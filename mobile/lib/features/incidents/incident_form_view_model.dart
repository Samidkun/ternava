import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/incident_input.dart';
import '../../core/sync/outbox_repository.dart';

/// Status of an optional photo attached to an incident.
/// The photo is tracked independently from the observation text.
enum PhotoState { none, queued, waitingForParent, uploaded, failed }

class IncidentFormViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  final OutboxRepository outbox;

  static const int maxPhotoBytes = 2 * 1024 * 1024;
  static const List<String> allowedPhotoTypes = ['image/jpeg', 'image/png'];

  final String _draftId = 'incident-draft';
  String _draftObservation = '';
  String? _errorMessage;
  bool _isSaving = false;
  bool _isComplete = false;

  List<int>? _photoBytes;
  String? _photoMediaType;
  PhotoState _photoState = PhotoState.none;

  IncidentFormViewModel({required this.apiClient, required this.outbox});

  String get draftObservation => _draftObservation;
  String? get errorMessage => _errorMessage;
  bool get isSaving => _isSaving;
  bool get isComplete => _isComplete;
  bool get hasPhoto => _photoBytes != null;
  String? get photoMediaType => _photoMediaType;
  PhotoState get photoState => _photoState;

  Future<void> loadDraft() async {
    final draft = outbox.getDraft(_draftId);
    _draftObservation = (draft?['observation'] as String?) ?? '';
    notifyListeners();
  }

  Future<void> saveDraft({required String observation}) async {
    _draftObservation = observation;
    await outbox.saveDraft(_draftId, {
      'id': _draftId,
      'observation': observation,
    });
    notifyListeners();
  }

  /// Attach a photo. The photo is validated and queued separately from the
  /// observation text; a rejected photo never discards the text.
  bool attachPhoto({required List<int> bytes, required String mediaType}) {
    if (!allowedPhotoTypes.contains(mediaType)) {
      _errorMessage = 'Gunakan JPEG atau PNG yang dapat dibuka.';
      notifyListeners();
      return false;
    }

    if (bytes.length > maxPhotoBytes) {
      _errorMessage = 'Foto maksimal 2 MiB.';
      notifyListeners();
      return false;
    }

    _photoBytes = bytes;
    _photoMediaType = mediaType;
    _photoState = PhotoState.queued;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Submit the observation text. The photo, if any, is uploaded separately
  /// after the parent is acknowledged.
  Future<bool> submit({
    required String cageId,
    String? flockId,
    String attention = 'routine',
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final id = 'incident-${DateTime.now().microsecondsSinceEpoch}';
    final key = 'incident-$id';

    final values = <String, Object?>{
      'id': id,
      'cage_id': cageId,
      'flock_id': flockId,
      'observed_at': DateTime.now().toUtc().toIso8601String(),
      'observation': _draftObservation.trim(),
      'attention': attention,
      'source_daily_record_id': null,
    };

    try {
      final payload = IncidentInput.fromJson(values);
      await apiClient.request(
        'createIncident',
        body: payload.toJson(),
        idempotencyKey: key,
      );
      if (hasPhoto) {
        // Photo upload waits for the parent ACK; it is never sent first.
        _photoState = PhotoState.waitingForParent;
      }
      _isComplete = true;
      return true;
    } on ApiFailure catch (e) {
      if (e.status == 0 || e.status >= 500) {
        await outbox.enqueue(Intent.incident(values, key));
        if (hasPhoto) {
          _photoState = PhotoState.waitingForParent;
        }
      }
      _errorMessage = e.message;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
