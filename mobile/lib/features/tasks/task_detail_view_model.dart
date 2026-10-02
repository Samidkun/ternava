import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/task_result_input.dart';
import '../../core/api/generated/types.dart';
import '../../core/sync/cache_repository.dart';
import '../../core/sync/outbox_repository.dart';

class TaskDetailViewModel extends ChangeNotifier {
  final CacheRepository cache;
  final OutboxRepository outbox;
  final ApiClient apiClient;
  final String runId;

  JsonObject? _run;
  String _runStatus = 'open';
  final Set<String> _checked = {};
  bool _isSubmitting = false;
  bool _needsReview = false;
  String? _errorMessage;

  TaskDetailViewModel({
    required this.cache,
    required this.outbox,
    required this.apiClient,
    required this.runId,
  });

  String get runStatus => _runStatus;
  bool get isSubmitting => _isSubmitting;
  bool get needsReview => _needsReview;
  String? get errorMessage => _errorMessage;

  /// A task is finished once a completed result was recorded, or the
  /// template run was cancelled. Finished tasks are read-only.
  bool get isReadOnly =>
      _runStatus == 'completed' || _runStatus == 'cancelled';

  String get title => (_run?['title'] as String?) ?? '';
  String get sop => (_run?['sop'] as String?) ?? '';

  List<JsonObject> get checklistItems {
    final raw = _run?['checklist_items'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().map((e) => e.cast<String, Object?>()).toList();
    }
    return const [];
  }

  bool isChecked(String itemId) => _checked.contains(itemId);

  Future<void> load() async {
    final runs = await cache.list('task_run');
    for (final run in runs) {
      if (run['id'] == runId) {
        _run = run;
        break;
      }
    }
    _runStatus = (_run?['status'] as String?) ?? 'open';
    _checked.clear();
    notifyListeners();
  }

  void toggle(String itemId, bool value) {
    if (isReadOnly) return;
    if (value) {
      _checked.add(itemId);
    } else {
      _checked.remove(itemId);
    }
    notifyListeners();
  }

  Future<bool> submit(TaskResultInput input) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    final body = input.toJson();
    final key = 'task-result-$runId-${DateTime.now().microsecondsSinceEpoch}';

    try {
      await apiClient.request(
        'createTaskResult',
        pathParams: {'id': runId},
        body: body,
        idempotencyKey: key,
      );
      if (body['status'] == 'completed') {
        _runStatus = 'completed';
      }
      return true;
    } on ApiFailure catch (e) {
      if (e.status == 0 || e.status >= 500) {
        await outbox.enqueue(Intent.taskResult(runId, body, key));
      } else if (e.status == 409) {
        // The run was cancelled or otherwise changed underneath us.
        _needsReview = true;
      }
      _errorMessage = e.message;
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
