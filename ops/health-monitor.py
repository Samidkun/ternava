#!/usr/bin/env python3
"""TERNAVA — incident metrics and alerting thresholds (T43, AC-45).

AC-45 requires the system to expose metrics/status that *distinguish* an API
failure, a queue failure, a backup failure and a push failure. A single "down"
flag is not enough: an operator must be able to tell which subsystem broke.

This tool reads the machine-readable state the runtime already writes —
the worker/scheduler heartbeat JSON (`php artisan ternava:heartbeat`) plus a
few cheap probes (backup age on disk, disk usage, recent 5xx count) — and emits
one status document with a separate verdict per subsystem and per threshold.

Thresholds come from docs/operations-security.md and MUST stay in sync with
ops/lib.sh (the shell constants are the canonical numbers for the ops scripts):

    queue oldest  > 5 min      -> queue alert
    heartbeat     > 3 min      -> heartbeat alert
    backup age    > 26 h       -> backup alert
    disk usage    > 80%        -> disk alert
    5xx over 5min > 5%         -> api alert
    push undelivered / devices disabled -> push degraded (NOT api down)

Usage:
    python3 ops/health-monitor.py --self-check     # deterministic self-test
    python3 ops/health-monitor.py --json           # emit status document
    python3 ops/health-monitor.py --heartbeats-dir <dir> --backup-dir <dir>

Exit codes: 0 = healthy (self-check passes / no alert), 1 = at least one alert,
2 = usage error. A push degradation alone does NOT fail the API verdict.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

# --- canonical thresholds (mirror ops/lib.sh + operations-security.md) --------
QUEUE_OLDEST_SECONDS = 300      # 5 min
HEARTBEAT_STALE_SECONDS = 180   # 3 min
BACKUP_AGE_SECONDS = 93600      # 26 h
DISK_PERCENT_LIMIT = 80         # > 80%
FIVEXX_PERCENT_LIMIT = 5.0      # > 5% over 5 min
SLO_TARGET_PERCENT = 99.5       # monthly API SLO (measured after the pilot runs)

SUBSYSTEMS = ("api", "queue", "backup", "push")


def _age_seconds(path: Path, now: float | None = None) -> float | None:
    """Seconds since mtime, or None when the file does not exist."""
    if not path.exists():
        return None
    now = time.time() if now is None else now
    return now - path.stat().st_mtime


def evaluate(
    *,
    now: float,
    heartbeats: dict[str, float | None],
    queue_oldest_seconds: float | None,
    backup_age_seconds: float | None,
    disk_percent: float | None,
    fivexx_percent: float | None,
    push_undelivered: int | None,
    push_degraded_devices: int | None,
) -> dict:
    """Pure threshold logic — no I/O, so the self-check can exercise it exactly.

    `heartbeats` maps role -> age in seconds (or None when the role's heartbeat
    file is missing). EVERY role must be present and fresh: a healthy scheduler
    must never hide a dead worker, and vice versa (AC-45).

    Returns a status document with a per-subsystem verdict. The whole point is
    that each subsystem is judged independently.
    """
    alerts: list[dict] = []

    def alert(kind: str, metric: str, value, limit, unit: str) -> None:
        alerts.append(
            {"kind": kind, "metric": metric, "value": value, "limit": limit, "unit": unit}
        )

    # API — driven by the 5xx ratio; heartbeat/queue are separate subsystems.
    api_ok = True
    if fivexx_percent is not None and fivexx_percent > FIVEXX_PERCENT_LIMIT:
        api_ok = False
        alert("api", "fivexx_percent", fivexx_percent, FIVEXX_PERCENT_LIMIT, "%/5min")

    # Queue — oldest pending job age.
    queue_ok = True
    if queue_oldest_seconds is not None and queue_oldest_seconds > QUEUE_OLDEST_SECONDS:
        queue_ok = False
        alert("queue", "queue_oldest_seconds", queue_oldest_seconds, QUEUE_OLDEST_SECONDS, "s")

    # Heartbeat — worker and scheduler liveness, judged SEPARATELY so a stuck
    # worker cannot hide behind a healthy scheduler.
    heartbeat_ok = True
    heartbeat_roles: dict[str, str] = {}
    for role in ("worker", "scheduler"):
        age = heartbeats.get(role)
        if age is None:
            heartbeat_ok = False
            heartbeat_roles[role] = "missing"
            alert("queue", f"heartbeat.{role}", "missing", HEARTBEAT_STALE_SECONDS, "s")
        elif age > HEARTBEAT_STALE_SECONDS:
            heartbeat_ok = False
            heartbeat_roles[role] = "stale"
            alert("queue", f"heartbeat.{role}", round(age, 1), HEARTBEAT_STALE_SECONDS, "s")
        else:
            heartbeat_roles[role] = "ok"

    # Backup — age of the newest bundle.
    backup_ok = True
    if backup_age_seconds is None:
        backup_ok = False
        alert("backup", "backup_age_seconds", "missing", BACKUP_AGE_SECONDS, "s")
    elif backup_age_seconds > BACKUP_AGE_SECONDS:
        backup_ok = False
        alert("backup", "backup_age_seconds", backup_age_seconds, BACKUP_AGE_SECONDS, "s")

    # Disk — capacity pressure.
    disk_ok = True
    if disk_percent is not None and disk_percent > DISK_PERCENT_LIMIT:
        disk_ok = False
        alert("disk", "disk_percent", disk_percent, DISK_PERCENT_LIMIT, "%")

    # Push — degradation is reported but NEVER marks the API down.
    push_ok = True
    if (push_undelivered or 0) > 0 or (push_degraded_devices or 0) > 0:
        push_ok = False
        alert(
            "push",
            "push_undelivered/degraded",
            {"undelivered": push_undelivered, "degraded_devices": push_degraded_devices},
            0,
            "count",
        )

    subsystems = {
        "api": "ok" if api_ok else "alert",
        "queue": "ok" if (queue_ok and heartbeat_ok) else "alert",
        "backup": "ok" if backup_ok else "alert",
        "push": "ok" if push_ok else "degraded",
    }
    # The overall service is down only when API or queue is broken. Backup and
    # push are reported separately (a dead FCM must not hide the API).
    service_down = (not api_ok) or (not queue_ok) or (not heartbeat_ok)

    return {
        "checked_at": now,
        "subsystems": subsystems,
        "heartbeat_roles": heartbeat_roles,
        "service": "down" if service_down else "up",
        "alerts": alerts,
        "thresholds": {
            "queue_oldest_seconds": QUEUE_OLDEST_SECONDS,
            "heartbeat_stale_seconds": HEARTBEAT_STALE_SECONDS,
            "backup_age_seconds": BACKUP_AGE_SECONDS,
            "disk_percent_limit": DISK_PERCENT_LIMIT,
            "fivexx_percent_limit": FIVEXX_PERCENT_LIMIT,
            "slo_target_percent": SLO_TARGET_PERCENT,
        },
    }


def disk_percent(path: Path) -> float:
    usage = shutil.disk_usage(str(path))
    return round(usage.used / usage.total * 100, 1)


def newest_backup_age(backup_dir: Path) -> float | None:
    if not backup_dir.exists():
        return None
    candidates = [p for p in backup_dir.iterdir() if p.name.startswith("ternava-")]
    if not candidates:
        return None
    newest = max(candidates, key=lambda p: p.stat().st_mtime)
    return _age_seconds(newest)


def heartbeat_ages(heartbeats_dir: Path) -> dict[str, float | None]:
    """Age in seconds for each monitored role, None when the file is missing."""
    return {
        role: _age_seconds(heartbeats_dir / f"{role}.json")
        for role in ("worker", "scheduler")
    }


def read_heartbeat_metrics(heartbeats_dir: Path) -> dict:
    merged: dict = {}
    for role in ("worker", "scheduler"):
        f = heartbeats_dir / f"{role}.json"
        if not f.exists():
            continue
        try:
            data = json.loads(f.read_text())
        except (json.JSONDecodeError, OSError):
            continue
        for k, v in (data.get("metrics") or {}).items():
            if v is not None:
                merged[k] = max(merged.get(k, 0), v)
    return merged


def collect(args: argparse.Namespace) -> dict:
    hb_dir = Path(args.heartbeats_dir)
    backup_dir = Path(args.backup_dir)
    metrics = read_heartbeat_metrics(hb_dir)
    return evaluate(
        now=time.time(),
        heartbeats=heartbeat_ages(hb_dir),
        queue_oldest_seconds=metrics.get("queue_oldest_seconds"),
        backup_age_seconds=newest_backup_age(backup_dir),
        disk_percent=disk_percent(Path(args.disk_path)),
        fivexx_percent=metrics.get("fivexx_percent"),
        push_undelivered=metrics.get("push_undelivered"),
        push_degraded_devices=metrics.get("push_degraded_devices"),
    )


def self_check() -> int:
    """Deterministic checks of the threshold logic — no clock, no filesystem.

    Each case asserts an observable verdict so the monitor's *behaviour* is
    proven, not merely its existence. If any assertion fails, exit 1.
    """
    now = 1_000_000.0
    failures: list[str] = []
    fresh: dict[str, float | None] = {"worker": 10.0, "scheduler": 10.0}

    def case(name: str, doc: dict, *, want_service: str, want: dict[str, str]) -> None:
        if doc["service"] != want_service:
            failures.append(f"{name}: service={doc['service']} want {want_service}")
        for sub, expected in want.items():
            got = doc["subsystems"][sub]
            if got != expected:
                failures.append(f"{name}: {sub}={got} want {expected}")

    # 1. All healthy.
    healthy = evaluate(
        now=now, heartbeats=fresh, queue_oldest_seconds=5, backup_age_seconds=3600,
        disk_percent=40.0, fivexx_percent=0.1, push_undelivered=0, push_degraded_devices=0,
    )
    case("healthy", healthy, want_service="up",
         want={"api": "ok", "queue": "ok", "backup": "ok", "push": "ok"})

    # 2. Queue stuck -> queue alert, API still up.
    stuck = evaluate(
        now=now, heartbeats=fresh, queue_oldest_seconds=QUEUE_OLDEST_SECONDS + 1,
        backup_age_seconds=3600, disk_percent=40.0,
        fivexx_percent=0.1, push_undelivered=0, push_degraded_devices=0,
    )
    case("queue-stuck", stuck, want_service="down", want={"queue": "alert", "api": "ok"})

    # 3. FCM down -> push degraded but API up and service up.
    fcm_down = evaluate(
        now=now, heartbeats=fresh, queue_oldest_seconds=5, backup_age_seconds=3600,
        disk_percent=40.0, fivexx_percent=0.1, push_undelivered=3, push_degraded_devices=0,
    )
    case("fcm-down", fcm_down, want_service="up", want={"api": "ok", "push": "degraded"})

    # 4. Stale backup -> backup alert, API up.
    stale_backup = evaluate(
        now=now, heartbeats=fresh, queue_oldest_seconds=5,
        backup_age_seconds=BACKUP_AGE_SECONDS + 1, disk_percent=40.0,
        fivexx_percent=0.1, push_undelivered=0, push_degraded_devices=0,
    )
    case("stale-backup", stale_backup, want_service="up", want={"backup": "alert", "api": "ok"})

    # 5. API 5xx spike -> api alert, service down.
    api_down = evaluate(
        now=now, heartbeats=fresh, queue_oldest_seconds=5, backup_age_seconds=3600,
        disk_percent=40.0, fivexx_percent=FIVEXX_PERCENT_LIMIT + 1, push_undelivered=0,
        push_degraded_devices=0,
    )
    case("api-5xx", api_down, want_service="down", want={"api": "alert"})

    # 6. A dead WORKER must not hide behind a healthy scheduler.
    dead_worker = evaluate(
        now=now, heartbeats={"worker": None, "scheduler": 10.0}, queue_oldest_seconds=5,
        backup_age_seconds=3600, disk_percent=40.0, fivexx_percent=0.1,
        push_undelivered=0, push_degraded_devices=0,
    )
    case("worker-dead", dead_worker, want_service="down", want={"queue": "alert"})
    if dead_worker["heartbeat_roles"].get("worker") != "missing":
        failures.append("worker-dead: worker role not flagged missing")
    if dead_worker["heartbeat_roles"].get("scheduler") != "ok":
        failures.append("worker-dead: scheduler should stay ok")

    # 7. A stale SCHEDULER (worker fine) is still an alert.
    stale_scheduler = evaluate(
        now=now, heartbeats={"worker": 10.0, "scheduler": HEARTBEAT_STALE_SECONDS + 1},
        queue_oldest_seconds=5, backup_age_seconds=3600, disk_percent=40.0,
        fivexx_percent=0.1, push_undelivered=0, push_degraded_devices=0,
    )
    case("scheduler-stale", stale_scheduler, want_service="down", want={"queue": "alert"})

    # 8. Each alert carries a kind — the four failure modes stay distinguishable.
    kinds = {a["kind"] for a in api_down["alerts"]}
    if "api" not in kinds:
        failures.append("distinguish: api alert missing its kind")

    if failures:
        for f in failures:
            print(f"FAIL: {f}", file=sys.stderr)
        print("SELF-CHECK: FAIL", file=sys.stderr)
        return 1

    print("SELF-CHECK: PASS — thresholds distinguish api/queue/backup/push; FCM degradation does not mark the API down.")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="TERNAVA incident metrics (AC-45)")
    parser.add_argument("--self-check", action="store_true",
                        help="run the deterministic threshold self-test and exit")
    parser.add_argument("--json", action="store_true", help="emit the status document")
    parser.add_argument("--heartbeats-dir", default=str(REPO_ROOT / "backend/storage/app/private/heartbeats"))
    parser.add_argument("--backup-dir", default=os.environ.get("TERNAVA_BACKUP_DIR", str(REPO_ROOT / "backups")))
    parser.add_argument("--disk-path", default=str(REPO_ROOT))
    args = parser.parse_args(argv)

    if args.self_check:
        return self_check()

    doc = collect(args)
    if args.json:
        print(json.dumps(doc, indent=2, sort_keys=True))
    else:
        print(f"service={doc['service']} " + " ".join(f"{k}={v}" for k, v in doc["subsystems"].items()))
    return 1 if doc["alerts"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
