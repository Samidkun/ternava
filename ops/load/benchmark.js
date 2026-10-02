// T44 — capacity & latency benchmark (AC-44).
//
// Target: 2 vCPU / 4 GiB API, 100k seeded daily records, 20 concurrent clients
// for 15 minutes. Success criteria:
//   * p95 read  <= 500 ms
//   * p95 write <= 1000 ms
//   * unexpected errors < 1%
//   * duplicate business effects == 0
//
// The API enforces a documented per-user budget (config ternava.limits
// .auth_per_minute = 120, applied by App\Http\Middleware\RequestLimits). The
// benchmark must therefore operate INSIDE that budget: a 429 is not a capacity
// failure, it is the guard doing its job, so this script paces each VU and
// counts 429 separately (rate_limited, threshold 0) instead of hiding it inside
// the error rate. Every other unexpected status is counted as unexpected_error.
//
// Each VU authenticates as its OWN user so the 20 clients do not share one
// budget. Each write targets a unique (flock, business_date) pair and is then
// replayed with the SAME Idempotency-Key; the replay must return the SAME
// record id, which is the duplicate-effect check.
//
// Usage:
//   k6 run ops/load/benchmark.js                       # 20 VUs / 15 min (default)
//   BASE_URL=http://127.0.0.1:8099 k6 run --vus 2 --duration 20s ops/load/benchmark.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { randomBytes } from 'k6/crypto';
import { Trend, Counter } from 'k6/metrics';

const creds = JSON.parse(open('../../backend/storage/app/private/load/credentials.json'));
const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:8099';
const REQ_PER_MIN = Number(__ENV.REQ_PER_MIN || 110); // safety margin under 120
const REQS_PER_ITER = 5; // 3 reads + 1 write + 1 replay

const readDuration = new Trend('read_duration', true);
const writeDuration = new Trend('write_duration', true);
const writeAccepted = new Counter('write_accepted');
const writeConflict = new Counter('write_conflict');
const rateLimited = new Counter('rate_limited');
const unexpectedError = new Counter('unexpected_error');
const duplicateEffect = new Counter('duplicate_effect');

export const options = {
  scenarios: {
    default: {
      executor: 'constant-vus',
      vus: Number(__ENV.VUS || 20),
      duration: __ENV.DURATION || '15m',
    },
  },
  thresholds: {
    read_duration: ['p(95)<=500'],
    write_duration: ['p(95)<=1000'],
    rate_limited: ['count<1'],
    unexpected_error: ['count<1'],
    duplicate_effect: ['count<1'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

function addDays(isoDate, days) {
  const d = new Date(isoDate + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

// Contract-valid idempotency key (openapi: format: uuid; the
// idempotency_receipts.operation_id column is a uuid). k6 v0.54.0's
// crypto.uuidv4 is a null object, so build a v4 UUID from randomBytes.
// One UUID per (VU, iteration); the write and its replay share it (AC-27).
function uuidFromVuIter(vu, iter) {
  const hex = Array.from(new Uint8Array(randomBytes(16)))
    .map((x) => x.toString(16).padStart(2, '0'))
    .join('');
  return (
    hex.slice(0, 8) + '-' +
    hex.slice(8, 12) + '-4' + hex.slice(13, 16) + '-a' + hex.slice(17, 20) + '-' +
    hex.slice(20, 32)
  );
}

export function setup() {
  const tokens = [];
  for (const username of creds.usernames) {
    const res = http.post(
      `${BASE_URL}/api/v1/session`,
      JSON.stringify({ username, password: creds.password }),
      { headers: { 'Content-Type': 'application/json' }, tags: { kind: 'setup' } },
    );
    if (res.status !== 200) {
      throw new Error(`login failed for ${username}: ${res.status} ${res.body}`);
    }
    tokens.push(res.json('data.token'));
  }
  // Run-unique day offset so repeated runs never collide on (flock, date);
  // the seeded rows live in 2020-2022, writes land well after that.
  const runDay = Math.floor(Date.now() / 1000) % 20000;
  return { tokens, runDay };
}

export default function (data) {
  const started = Date.now();
  const token = data.tokens[(__VU - 1) % data.tokens.length];
  const authHeaders = { Authorization: `Bearer ${token}` };
  const jsonHeaders = { ...authHeaders, 'Content-Type': 'application/json' };

  // --- READ PATH -----------------------------------------------------------
  const reads = [
    `${BASE_URL}/api/v1/daily-records?from=2020-01-01&to=2020-06-01&limit=100`,
    `${BASE_URL}/api/v1/sync/bootstrap?limit=50`,
    `${BASE_URL}/api/v1/feed-balances`,
  ];
  for (const url of reads) {
    const res = http.get(url, { headers: authHeaders, tags: { kind: 'read' } });
    if (res.status === 429) {
      rateLimited.add(1);
      continue;
    }
    readDuration.add(res.timings.duration);
    const ok = check(res, { 'read 2xx': (r) => r.status >= 200 && r.status < 300 });
    if (!ok) unexpectedError.add(1);
  }

  // --- WRITE PATH ----------------------------------------------------------
  const flock = creds.flock_ids[(__VU - 1) % creds.flock_ids.length];
  const businessDate = addDays(creds.write_base_date, data.runDay + __ITER);
  // The contract requires Idempotency-Key to be a UUID (openapi: format: uuid;
  // the idempotency_receipts.operation_id column is a uuid). A stable UUID per
  // (VU, iteration) keeps the write unique AND lets the replay reuse the key.
  const idemKey = uuidFromVuIter(__VU, __ITER);
  const body = JSON.stringify({
    flock_id: flock,
    business_date: businessDate,
    feed_type_id: creds.feed_type_id,
    feed_kg: '5.00',
    eggs_count: 800,
    condition: 'normal',
  });

  const res = http.post(`${BASE_URL}/api/v1/daily-records`, body, {
    headers: { ...jsonHeaders, 'Idempotency-Key': idemKey },
    tags: { kind: 'write' },
  });

  if (res.status === 429) {
    rateLimited.add(1);
  } else {
    writeDuration.add(res.timings.duration);
    if (res.status === 200) {
      writeAccepted.add(1);
      const id = res.json('data.id');
      const replay = http.post(`${BASE_URL}/api/v1/daily-records`, body, {
        headers: { ...jsonHeaders, 'Idempotency-Key': idemKey },
        tags: { kind: 'write' },
      });
      if (replay.status === 429) {
        rateLimited.add(1);
      } else if (replay.status !== 200) {
        unexpectedError.add(1);
      } else if (replay.json('data.id') !== id) {
        duplicateEffect.add(1);
      }
    } else if (res.status === 409) {
      writeConflict.add(1);
    } else {
      unexpectedError.add(1);
    }
  }

  // Pace to stay under the documented per-user budget.
  const targetMs = (REQS_PER_ITER / (REQ_PER_MIN / 60)) * 1000;
  const elapsed = Date.now() - started;
  if (elapsed < targetMs) sleep((targetMs - elapsed) / 1000);
}
