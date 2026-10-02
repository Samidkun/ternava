import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/task_template_input.dart';
import '../../core/api/generated/types.dart';
import '../../core/sync/outbox_repository.dart';

class TaskFormViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  final OutboxRepository outbox;

  bool _isSaving = false;
  String? _errorMessage;
  bool _isComplete = false;
  String? _persistKey;

  TaskFormViewModel({
    required this.apiClient,
    required this.outbox,
  });

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get isComplete => _isComplete;

  String _newKey() => 'task-template-${DateTime.now().microsecondsSinceEpoch}';

  /// Templates are master data and are saved online only; there is no
  /// offline queue for them.
  Future<bool> save(JsonObject input) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    _persistKey ??= _newKey();

    try {
      final payload = TaskTemplateInput.fromJson(input);
      await apiClient.request(
        'createTaskTemplate',
        body: payload.toJson(),
        idempotencyKey: _persistKey,
      );
      _isComplete = true;
      _persistKey = null;
      return true;
    } on ApiFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
