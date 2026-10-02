import 'dart:async';

import '../api/api_failure.dart';
import '../api/generated/types.dart';
import 'outbox_repository.dart';
import 'retry_policy.dart';

abstract class Transport {
  Future<JsonObject> send(
    String operationId,
    JsonObject payload,
    String idempotencyKey,
  );
}

class SyncWorker {
  final OutboxRepository outbox;
  final Transport transport;
  final RetryPolicy retryPolicy;

  SyncWorker({
    required this.outbox,
    required this.transport,
    required this.retryPolicy,
  });

  Future<void> runOnce() async {
    await outbox.recoverSending();
    final pending = await outbox.pendingIntents();

    for (final intent in pending) {
      await outbox.markSending(intent.id);
      try {
        final ack = await transport.send(
          intent.operationId,
          intent.payload,
          intent.id,
        );
        await outbox.markAccepted(intent.id, ack);
      } on ApiFailure catch (e) {
        final decision = retryPolicy.next(e, intent.attempts + 1);
        final needsReview =
            decision.action == RetryAction.needsReview ||
            decision.action == RetryAction.stopBlockedAuth;
        await outbox.markFailed(intent.id, e.message, needsReview);
      } catch (e) {
        await outbox.markFailed(intent.id, e.toString(), false);
      }
    }
  }
}
