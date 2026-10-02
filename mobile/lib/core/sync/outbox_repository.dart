import 'dart:async';

import '../api/generated/types.dart';
import '../local/partition_store.dart';

enum IntentState {
  pending,
  sending,
  accepted,
  failed,
  needsReview,
}

class Intent {
  final String id; // Stable idempotency key
  final String resourceId;
  final String operationId;
  final JsonObject payload;
  final List<String> dependencies;
  IntentState state;
  int attempts;
  String? lastError;
  final DateTime createdAt;
  DateTime updatedAt;

  Intent({
    required this.id,
    required this.resourceId,
    required this.operationId,
    required this.payload,
    this.dependencies = const [],
    this.state = IntentState.pending,
    this.attempts = 0,
    this.lastError,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Intent.onlineMaster(
    String operationId,
    JsonObject payload,
    String idempotencyKey,
  ) {
    final resourceId = (payload['id'] as String?) ??
        '$operationId-${DateTime.now().microsecondsSinceEpoch}';
    return Intent(
      id: idempotencyKey,
      resourceId: resourceId,
      operationId: operationId,
      payload: payload,
    );
  }

  factory Intent.daily(JsonObject payload, {required String operationId}) {
    final resourceId = (payload['id'] as String?) ??
        'daily-${DateTime.now().microsecondsSinceEpoch}';
    return Intent(
      id: 'daily-${DateTime.now().microsecondsSinceEpoch}',
      resourceId: resourceId,
      operationId: operationId,
      payload: payload,
    );
  }

  factory Intent.taskResult(
    String runId,
    JsonObject payload,
    String idempotencyKey,
  ) {
    return Intent(
      id: idempotencyKey,
      resourceId: runId,
      operationId: 'createTaskResult',
      payload: payload,
    );
  }

  Intent copyWith({
    IntentState? state,
    int? attempts,
    String? lastError,
    DateTime? updatedAt,
  }) {
    return Intent(
      id: id,
      resourceId: resourceId,
      operationId: operationId,
      payload: payload,
      dependencies: dependencies,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class OutboxRepository {
  final PartitionStore store;
  final Map<String, Intent> _queue = {};
  final Map<String, JsonObject> _drafts = {};

  OutboxRepository({required this.store});

  Future<void> enqueue(Intent intent) async {
    await store.transaction(() async {
      _drafts[intent.resourceId] = intent.payload;
      _queue[intent.id] = intent;
    });
  }

  Future<void> recoverSending() async {
    for (final entry in _queue.entries) {
      if (entry.value.state == IntentState.sending) {
        entry.value.state = IntentState.pending;
        entry.value.updatedAt = DateTime.now();
      }
    }
  }

  Future<List<Intent>> allIntents() async {
    return _queue.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> retryIntent(String id) async {
    final intent = _queue[id];
    if (intent != null) {
      intent.state = IntentState.pending;
      intent.lastError = null;
      intent.updatedAt = DateTime.now();
    }
  }

  Future<void> cancelIntent(String id) async {
    await store.transaction(() async {
      final intent = _queue.remove(id);
      if (intent != null) {
        _drafts.remove(intent.resourceId);
      }
    });
  }

  Future<List<Intent>> pendingIntents() async {
    final pending = _queue.values
        .where((i) => i.state == IntentState.pending)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  Future<void> markSending(String id) async {
    final intent = _queue[id];
    if (intent != null) {
      intent.state = IntentState.sending;
      intent.updatedAt = DateTime.now();
    }
  }

  Future<void> markAccepted(String id, JsonObject ack) async {
    await store.transaction(() async {
      final intent = _queue[id];
      if (intent != null) {
        intent.state = IntentState.accepted;
        intent.updatedAt = DateTime.now();
        // Clear draft since accepted on server
        _drafts.remove(intent.resourceId);
      }
    });
  }

  Future<void> markFailed(String id, String error, bool needsReview) async {
    final intent = _queue[id];
    if (intent != null) {
      intent.attempts += 1;
      intent.lastError = error;
      intent.state =
          needsReview ? IntentState.needsReview : IntentState.pending;
      intent.updatedAt = DateTime.now();
    }
  }

  JsonObject? getDraft(String resourceId) => _drafts[resourceId];
}
