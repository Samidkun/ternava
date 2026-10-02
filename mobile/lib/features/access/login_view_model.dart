import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/local/partition_store.dart';
import '../../core/sync/bootstrap_coordinator.dart';

class LoginViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  final BootstrapCoordinator coordinator;
  final PartitionStore store;

  bool _isLoading = false;
  String? _errorMessage;
  bool _mustChangePassword = false;

  LoginViewModel({
    required this.apiClient,
    required this.coordinator,
    required this.store,
  });

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get mustChangePassword => _mustChangePassword;

  Future<void> submit(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.request(
        'login',
        body: {'username': username, 'password': password},
      );

      final data = res['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      apiClient.setAuthToken(token);

      final actor = data['actor'] as Map<String, dynamic>;
      final partition = PartitionId(
        actorId: actor['id'] as String,
        farmId: actor['farm_id'] as String,
      );
      await store.unlock(partition);

      _mustChangePassword = data['must_change_password'] as bool? ?? false;
      if (!_mustChangePassword) {
        await coordinator.refresh();
      }
    } on ApiFailure catch (e) {
      if (e.status == 0) {
        _errorMessage = 'Sambungkan internet untuk masuk pertama kali.';
      } else if (e.status == 401) {
        _errorMessage = 'Nama pengguna atau kata sandi tidak cocok.';
      } else {
        _errorMessage = e.message;
      }
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan sistem.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await apiClient.request(
        'changePassword',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      _mustChangePassword = false;
      await coordinator.refresh();
    } on ApiFailure catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
