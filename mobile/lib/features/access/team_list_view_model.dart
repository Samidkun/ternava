import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/generated/types.dart';
import '../../core/sync/outbox_repository.dart';

class TeamListViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  final OutboxRepository outbox;

  List<JsonObject> _members = [];
  bool _isLoading = false;

  TeamListViewModel({
    required this.apiClient,
    required this.outbox,
  });

  List<JsonObject> get members => _members;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await apiClient.request('listMember');
      final data = res['data'];
      if (data is List) {
        _members = data
            .whereType<Map<String, dynamic>>()
            .map<JsonObject>((e) => e)
            .toList();
      } else {
        _members = [];
      }
    } catch (_) {
      _members = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
