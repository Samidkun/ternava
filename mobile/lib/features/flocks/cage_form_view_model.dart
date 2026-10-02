import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/types.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/sync/sync_worker.dart';

class CageFormViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  final OutboxRepository outbox;
  final SyncWorker worker;

  bool _isSaving = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = {};
  bool _isComplete = false;
  String? _persistKey;

  CageFormViewModel({
    required this.apiClient,
    required this.outbox,
    required this.worker,
  });

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  Map<String, String> get fieldErrors => _fieldErrors;
  bool get isComplete => _isComplete;

  String _newKey() => 'cage-${DateTime.now().microsecondsSinceEpoch}';

  Future<bool> save(JsonObject input, {bool edit = false, String? id}) async {
    _isSaving = true;
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();

    _persistKey ??= _newKey();

    try {
      await apiClient.request(
        edit ? 'updateCage' : 'createCage',
        pathParams: edit && id != null ? {'id': id} : null,
        body: input,
        idempotencyKey: _persistKey,
      );
      _isComplete = true;
      _persistKey = null;
      return true;
    } on ApiFailure catch (e) {
      if (e.status == 0 || e.status >= 500) {
        await outbox.enqueue(
          Intent.onlineMaster(edit ? 'updateCage' : 'createCage', input, _persistKey!),
        );
      }
      if (e.fields != null) {
        _fieldErrors = e.fields!.map(
          (k, v) => MapEntry(k, v is List ? v.first.toString() : v.toString()),
        );
        // Field-level errors render inline; avoid duplicating them in the
        // banner above the form.
        _errorMessage = null;
      } else {
        _errorMessage = e.message;
      }
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
