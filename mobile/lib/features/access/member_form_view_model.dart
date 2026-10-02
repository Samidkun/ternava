import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/member_input.dart';
import '../../core/api/generated/member_update.dart';
import '../../core/api/generated/types.dart';
import '../../core/sync/outbox_repository.dart';

/// Sensitive keys that must NEVER be written to the local outbox.
const _sensitiveKeys = {'temporary_password', 'password', 'new_password'};

class MemberFormViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  final OutboxRepository outbox;
  final String role;

  bool _isSaving = false;
  String? _errorMessage;
  bool _isComplete = false;
  String? _creationKey;

  MemberFormViewModel({
    required this.apiClient,
    required this.outbox,
    required this.role,
  });

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get isComplete => _isComplete;

  /// Admins may only assign the operator role; owners may assign operator or
  /// admin (never a second owner — the backend enforces this too).
  List<String> get assignableRoles {
    if (role == 'admin') return const ['operator'];
    return const ['operator', 'admin'];
  }

  String _newKey() => 'member-${DateTime.now().microsecondsSinceEpoch}';

  String ensureCreationKey() => _creationKey ??= _newKey();

  Future<bool> create(JsonObject values) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final password = values['temporary_password'] as String? ?? '';
    if (password.length < 12) {
      _errorMessage = 'Kata sandi sementara minimal 12 karakter.';
      _isSaving = false;
      notifyListeners();
      return false;
    }

    final key = ensureCreationKey();

    try {
      final payload = MemberInput.fromJson(values);
      await apiClient.request(
        'createMember',
        body: payload.toJson(),
        idempotencyKey: key,
      );
      _isComplete = true;
      _creationKey = null;
      return true;
    } on ApiFailure catch (e) {
      // SECURITY: never persist the password-bearing payload locally.
      // The idempotency key alone lets a retry resolve by username/server
      // state instead of replaying a secret.
      _errorMessage = e.message;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> update(JsonObject values, {required String id}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = MemberUpdate.fromJson(values);
      await apiClient.request(
        'updateMember',
        pathParams: {'id': id},
        body: payload.toJson(),
        idempotencyKey: ensureCreationKey(),
      );
      _isComplete = true;
      _creationKey = null;
      return true;
    } on ApiFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Strips sensitive fields before any potential local persistence.
  static JsonObject stripSecrets(JsonObject values) {
    return Map<String, Object?>.fromEntries(
      values.entries.where((e) => !_sensitiveKeys.contains(e.key)),
    );
  }
}
