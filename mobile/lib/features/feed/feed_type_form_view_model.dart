import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/feed_type_input.dart';
import '../../core/api/generated/feed_type_update.dart';
import '../../core/api/generated/types.dart';
import '../../core/sync/outbox_repository.dart';

class FeedTypeFormViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  final OutboxRepository outbox;
  final bool edit;
  final Map<String, dynamic>? initial;

  bool _isSaving = false;
  String? _errorMessage;
  bool _isComplete = false;
  String? _persistKey;

  FeedTypeFormViewModel({
    required this.apiClient,
    required this.outbox,
    this.edit = false,
    this.initial,
  });

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get isComplete => _isComplete;

  int get baseVersion => (initial?['version'] as num?)?.toInt() ?? 1;

  /// Threshold alerts are driven by a *transition* of the balance across the
  /// threshold (crossing down), never by merely refreshing the stock view.
  /// This keeps a persistent low balance from re-alerting on every refresh.
  bool isBelowThreshold(String balanceKg, String thresholdKg) {
    final balance = double.tryParse(balanceKg);
    final threshold = double.tryParse(thresholdKg);
    if (balance == null || threshold == null) return false;
    return balance < threshold;
  }

  String _newKey() => 'feed-type-${DateTime.now().microsecondsSinceEpoch}';

  Future<bool> save(JsonObject input) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    _persistKey ??= _newKey();

    final threshold = input['min_threshold_kg'];
    if (threshold != null && double.tryParse('$threshold') == null) {
      _errorMessage = 'Ambang minimum tidak valid.';
      _isSaving = false;
      notifyListeners();
      return false;
    }

    try {
      if (edit) {
        final payload = FeedTypeUpdate.fromJson({
          ...input,
          'base_version': baseVersion,
        });
        await apiClient.request(
          'updateFeedType',
          pathParams: {'id': initial?['id'] as String? ?? ''},
          body: payload.toJson(),
          idempotencyKey: _persistKey,
        );
      } else {
        final payload = FeedTypeInput.fromJson(input);
        await apiClient.request(
          'createFeedType',
          body: payload.toJson(),
          idempotencyKey: _persistKey,
        );
      }
      _isComplete = true;
      _persistKey = null;
      return true;
    } on ApiFailure catch (e) {
      if (e.status == 0 || e.status >= 500) {
        await outbox.enqueue(
          Intent.onlineMaster(
            edit ? 'updateFeedType' : 'createFeedType',
            input,
            _persistKey!,
          ),
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
