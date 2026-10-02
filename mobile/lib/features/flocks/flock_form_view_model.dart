import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/flock_update.dart';
import '../../core/api/generated/types.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/sync/sync_worker.dart';

class FlockFormViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  final OutboxRepository outbox;
  final SyncWorker worker;
  final bool edit;
  final Map<String, dynamic>? initial;

  bool _isSaving = false;
  String? _errorMessage;
  bool _isComplete = false;
  String? _persistKey;

  FlockFormViewModel({
    required this.apiClient,
    required this.outbox,
    required this.worker,
    this.edit = false,
    this.initial,
  });

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get isComplete => _isComplete;

  /// Initial population becomes immutable once the flock has recorded
  /// operations — the form must lock it (AM-02).
  bool get initialPopulationLocked =>
      edit && (initial?['has_operations'] as bool? ?? false);

  int get baseVersion => (initial?['version'] as num?)?.toInt() ?? 1;

  String _newKey() => 'flock-${DateTime.now().microsecondsSinceEpoch}';

  Future<bool> save(JsonObject values, {String? reason}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    _persistKey ??= _newKey();

    try {
      if (edit) {
        final payload = FlockUpdate.fromJson({
          ...values,
          'base_version': baseVersion,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        });
        await apiClient.request(
          'updateFlock',
          pathParams: {'id': initial?['id'] as String? ?? ''},
          body: payload.toJson(),
          idempotencyKey: _persistKey,
        );
      } else {
        await apiClient.request(
          'createFlock',
          body: values,
          idempotencyKey: _persistKey,
        );
      }
      _isComplete = true;
      _persistKey = null;
      return true;
    } on ApiFailure catch (e) {
      if (e.status == 0 || e.status >= 500) {
        await outbox.enqueue(Intent.onlineMaster(
            edit ? 'updateFlock' : 'createFlock', values, _persistKey!));
      }
      _errorMessage = e.message;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> finish(String endDate, {required bool confirmed}) async {
    if (!confirmed) return false;
    return save(
      {'status': 'finished', 'end_date': endDate},
      reason: 'Kelompok selesai',
    );
  }
}
