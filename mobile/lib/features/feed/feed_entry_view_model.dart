import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/feed_entry_input.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/sync/sync_worker.dart';

class FeedEntryViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  final OutboxRepository outbox;
  final SyncWorker worker;

  bool _isSaving = false;
  String? _errorMessage;
  bool _isComplete = false;
  String? _persistKey;

  FeedEntryViewModel({
    required this.apiClient,
    required this.outbox,
    required this.worker,
  });

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get isComplete => _isComplete;

  String _newKey() => 'feed-${DateTime.now().microsecondsSinceEpoch}';

  Future<bool> save({
    required String feedTypeId,
    required String kind,
    required String amountKg,
    String? note,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    // Client-side guard: an amount must be a valid non-negative decimal.
    final parsed = double.tryParse(amountKg.trim());
    if (parsed == null || parsed < 0) {
      _errorMessage = 'Jumlah pakan tidak valid.';
      _isSaving = false;
      notifyListeners();
      return false;
    }

    _persistKey ??= _newKey();

    final values = <String, Object?>{
      'feed_type_id': feedTypeId,
      'kind': kind,
      'amount_kg': amountKg.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    try {
      final payload = FeedEntryInput.fromJson(values);
      await apiClient.request(
        'createFeedEntry',
        body: payload.toJson(),
        idempotencyKey: _persistKey,
      );
      _isComplete = true;
      _persistKey = null;
      return true;
    } on ApiFailure catch (e) {
      // Offline / server failure: queue for later, preserving input.
      if (e.status == 0 || e.status >= 500) {
        await outbox.enqueue(
          Intent.onlineMaster('createFeedEntry', values, _persistKey!),
        );
      }
      _errorMessage = e.message;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
