import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/local/partition_store.dart';

class AccountViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  final PartitionStore store;
  Map<String, dynamic>? _userProfile;

  AccountViewModel({required this.apiClient, required this.store});

  Map<String, dynamic>? get userProfile => _userProfile;

  Future<void> loadProfile() async {
    try {
      final res = await apiClient.request('session');
      _userProfile = res['data'] as Map<String, dynamic>?;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout({required bool confirmed}) async {
    if (!confirmed) return;
    try {
      await apiClient.request('logout');
    } catch (_) {}
    await store.lock();
    apiClient.setAuthToken(null);
    notifyListeners();
  }
}
