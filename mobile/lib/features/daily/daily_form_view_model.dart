import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/quantity/kg.dart';
import '../../core/sync/outbox_repository.dart';

class DailyFormViewModel extends ChangeNotifier {
  final OutboxRepository outbox;
  final String flockId;
  final String cageName;
  final String businessDate;

  bool _isSaving = false;
  String? _errorMessage;

  DailyFormViewModel({
    required this.outbox,
    required this.flockId,
    required this.cageName,
    required this.businessDate,
  });

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<bool> submit({
    required String feedKgText,
    required String eggsCountText,
    String? mortalityCountText,
    String condition = 'normal',
    String? notes,
  }) async {
    _errorMessage = null;

    if (feedKgText.trim().isEmpty) {
      _errorMessage = 'Isi jumlah pakan dalam kg.';
      notifyListeners();
      return false;
    }

    try {
      Kg.parse(feedKgText.trim());
    } catch (_) {
      _errorMessage = 'Gunakan kg dengan dua angka desimal (misal 12.50).';
      notifyListeners();
      return false;
    }

    final eggs = int.tryParse(eggsCountText.trim());
    if (eggs == null || eggs < 0) {
      _errorMessage = 'Jumlah butir telur harus diisi angka bulat >= 0.';
      notifyListeners();
      return false;
    }

    final mortality =
        mortalityCountText != null && mortalityCountText.trim().isNotEmpty
        ? int.tryParse(mortalityCountText.trim())
        : null;

    _isSaving = true;
    notifyListeners();

    try {
      final resourceId = 'daily-${DateTime.now().millisecondsSinceEpoch}';
      final intent = Intent(
        id: 'intent-${DateTime.now().microsecondsSinceEpoch}',
        resourceId: resourceId,
        operationId: 'createDaily',
        payload: {
          'id': resourceId,
          'flock_id': flockId,
          'business_date': businessDate,
          'feed_type_id': 'default-feed-type',
          'feed_kg': feedKgText.trim(),
          'eggs_count': eggs,
          'mortality_count': mortality,
          'condition': condition,
          'notes': notes,
        },
      );

      await outbox.enqueue(intent);
      return true;
    } catch (_) {
      _errorMessage = 'Gagal menyimpan ke penyimpanan lokal.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> saveDraft({
    required String feedKgText,
    required String eggsCountText,
    String? notes,
  }) async {
    final resourceId = 'draft-$flockId-$businessDate';
    final intent = Intent(
      id: 'draft-${DateTime.now().microsecondsSinceEpoch}',
      resourceId: resourceId,
      operationId: 'saveDraft',
      payload: {
        'flock_id': flockId,
        'business_date': businessDate,
        'feed_kg': feedKgText,
        'eggs_count': eggsCountText,
        'notes': notes,
      },
    );
    await outbox.enqueue(intent);
  }
}
