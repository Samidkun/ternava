import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/outbox_repository.dart';
import 'package:mobile/core/sync/retry_policy.dart';
import 'package:mobile/core/sync/sync_worker.dart';

void main() {
  group('Outbox & RetryPolicy tests', () {
    test('relaunch recovers stuck sending state to pending', () async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'act-1', farmId: 'farm-1'));
      final outbox = OutboxRepository(store: store);

      final intent = Intent(
        id: 'key-1234',
        resourceId: 'res-daily-1',
        operationId: 'createDaily',
        payload: {'feed_kg': '15.00'},
      );

      await outbox.enqueue(intent);
      await outbox.markSending(intent.id);

      var pending = await outbox.pendingIntents();
      expect(pending, isEmpty); // In sending state, not pending

      // App crash / relaunch recovery
      await outbox.recoverSending();

      pending = await outbox.pendingIntents();
      expect(pending, hasLength(1));
      expect(pending.first.id, 'key-1234');
      expect(pending.first.state, IntentState.pending);
    });

    test('retry policy handles 401/403, 409/422, and 429 Retry-After', () {
      final policy = RetryPolicy();

      // 401 stops retry
      const authFail = ApiFailure(
        code: 'UNAUTHORIZED',
        message: 'Token expired',
        status: 401,
      );
      expect(policy.next(authFail, 1).action, RetryAction.stopBlockedAuth);

      // 409 or 422 needs manual review (never blind retry)
      const conflictFail = ApiFailure(
        code: 'DAILY_ALREADY_EXISTS',
        message: 'Duplikat',
        status: 409,
      );
      expect(policy.next(conflictFail, 1).action, RetryAction.needsReview);

      // 429 respects Retry-After
      const rateFail = ApiFailure(
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Too many requests',
        status: 429,
        retryAfter: 45,
      );
      final rateDecision = policy.next(rateFail, 1);
      expect(rateDecision.action, RetryAction.retryAfter);
      expect(rateDecision.delay, const Duration(seconds: 45));

      // Network error retries with backoff
      const netFail = ApiFailure(
        code: 'NETWORK_ERROR',
        message: 'Connection dropped',
        status: 0,
        retryable: true,
      );
      expect(policy.next(netFail, 1).action, RetryAction.retryLater);
    });

    test(
      'sync worker processes pending intent with stable key and marks accepted',
      () async {
        final store = PartitionStore();
        await store.unlock(
          const PartitionId(actorId: 'act-1', farmId: 'farm-1'),
        );
        final outbox = OutboxRepository(store: store);

        final intent = Intent(
          id: 'stable-key-uuid-1',
          resourceId: 'daily-id-1',
          operationId: 'createDaily',
          payload: {'feed_kg': '10.00', 'eggs_count': 80},
        );

        await outbox.enqueue(intent);

        final mockTransport = MockTransport();
        final worker = SyncWorker(
          outbox: outbox,
          transport: mockTransport,
          retryPolicy: RetryPolicy(),
        );

        await worker.runOnce();

        expect(mockTransport.sentKeys, ['stable-key-uuid-1']);
        final pendingAfter = await outbox.pendingIntents();
        expect(
          pendingAfter,
          isEmpty,
        ); // Accepted intents are removed from pending
      },
    );
  });
}

class MockTransport implements Transport {
  final List<String> sentKeys = [];

  @override
  Future<JsonObject> send(
    String operationId,
    JsonObject payload,
    String idempotencyKey,
  ) async {
    sentKeys.add(idempotencyKey);
    return {
      'data': {'status': 'accepted', 'version': 1},
    };
  }
}
