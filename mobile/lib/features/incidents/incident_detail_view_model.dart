import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/incident_action_input.dart';
import '../../core/api/generated/incident_assignment_input.dart';
import '../../core/api/generated/types.dart';
import '../../core/sync/cache_repository.dart';
import '../../core/sync/outbox_repository.dart';

class IncidentDetailViewModel extends ChangeNotifier {
  final CacheRepository cache;
  final OutboxRepository outbox;
  final ApiClient apiClient;
  final String incidentId;
  final String role;
  final String actorId;

  JsonObject? _incident;
  String _status = 'open';
  int _version = 1;
  bool _hasConflict = false;
  bool _isInaccessible = false;
  String? _pendingNotes;
  String? _errorMessage;
  bool _isSubmitting = false;

  IncidentDetailViewModel({
    required this.cache,
    required this.outbox,
    required this.apiClient,
    required this.incidentId,
    required this.role,
    this.actorId = '',
  });

  String get status => _status;
  int get version => _version;
  bool get hasConflict => _hasConflict;
  bool get isInaccessible => _isInaccessible;
  String? get pendingNotes => _pendingNotes;
  String? get errorMessage => _errorMessage;
  bool get isSubmitting => _isSubmitting;

  String get observation => (_incident?['observation'] as String?) ?? '';
  String? get assigneeId => _incident?['assignee_id'] as String?;

  bool get isManager => role == 'owner' || role == 'admin';

  bool get isReadOnly => _status == 'closed';

  /// A manager can always act; an operator only on incidents assigned to them.
  bool get canAct {
    if (isReadOnly) return false;
    if (isManager) return true;
    return assigneeId != null && assigneeId == actorId;
  }

  bool get canAssign => isManager && !isReadOnly;

  Future<void> load() async {
    final incidents = await cache.list('incident');
    for (final incident in incidents) {
      if (incident['id'] == incidentId) {
        _incident = incident;
        break;
      }
    }
    _status = (_incident?['status'] as String?) ?? 'open';
    _version = (_incident?['version'] as num?)?.toInt() ?? 1;
    notifyListeners();
  }

  Future<bool> assign(IncidentAssignmentInput input) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    final body = input.toJson();
    final key =
        'incident-assign-$incidentId-${DateTime.now().microsecondsSinceEpoch}';

    try {
      await apiClient.request(
        'assignIncident',
        pathParams: {'id': incidentId},
        body: body,
        idempotencyKey: key,
      );
      await load();
      return true;
    } on ApiFailure catch (e) {
      _handleFailure(e, body);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> act(IncidentActionInput input) async {
    final body = input.toJson();
    final status = body['status'] as String?;
    final notes = (body['notes'] as String?)?.trim() ?? '';

    // Closing requires an explanatory note.
    if (status == 'closed' && notes.isEmpty) {
      _errorMessage = 'Jelaskan tindakan sebelum menutup temuan.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    final key =
        'incident-action-$incidentId-${DateTime.now().microsecondsSinceEpoch}';

    try {
      await apiClient.request(
        'createIncidentAction',
        pathParams: {'id': incidentId},
        body: body,
        idempotencyKey: key,
      );
      _status = status ?? _status;
      _hasConflict = false;
      _pendingNotes = null;
      return true;
    } on ApiFailure catch (e) {
      _handleFailure(e, body, notes: notes);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _handleFailure(ApiFailure e, JsonObject body, {String notes = ''}) {
    if (e.status == 0 || e.status >= 500) {
      outbox.enqueue(
        Intent.incidentAction(
          incidentId,
          body,
          'incident-action-$incidentId-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
    } else if (e.status == 409) {
      // A version conflict: keep the user's notes and let them reload.
      _hasConflict = true;
      _pendingNotes = notes.isEmpty ? (body['notes'] as String?) : notes;
    } else if (e.status == 404) {
      // The incident is gone or access was revoked.
      _isInaccessible = true;
    }
    _errorMessage = e.message;
  }
}
