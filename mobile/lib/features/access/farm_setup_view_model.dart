import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/types.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/sync/sync_worker.dart';

class FarmSetupViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  final OutboxRepository outbox;
  final SyncWorker worker;

  bool _isSaving = false;
  String? _errorMessage;
  bool _isComplete = false;

  /// Stable idempotency key so retries after an unknown response never
  /// create a duplicate farm.
  String? _persistKey;

  FarmSetupViewModel({
    required this.apiClient,
    required this.outbox,
    required this.worker,
  });

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get isComplete => _isComplete;

  String ensurePersistKey() {
    return _persistKey ??= _newUuid();
  }

  String _newUuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = identityHashCode(this).toRadixString(16);
    return 'farm-$now-$rand';
  }

  Future<bool> save(JsonObject input) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final key = ensurePersistKey();
    final payload = Map<String, Object?>.from(input);

    try {
      await apiClient.request('updateFarm', body: payload, idempotencyKey: key);
      _isComplete = true;
      _persistKey = null;
      return true;
    } on ApiFailure catch (e) {
      // For unknown/transient outcomes, keep the same key and persist the
      // intent so the retry resolves by idempotency rather than duplicating.
      if (e.status == 0 || e.status >= 500) {
        await outbox.enqueue(Intent.onlineMaster('updateFarm', payload, key));
      }
      _errorMessage = e.message;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
