import 'package:flutter/foundation.dart';

import '../../core/api/generated/types.dart';
import '../../core/sync/cache_repository.dart';

class DailyHistoryRow {
  final String id;
  final String cageId;
  final String businessDate;
  final String feedKg;
  final int eggsCount;
  final bool pendingLocal;

  const DailyHistoryRow({
    required this.id,
    required this.cageId,
    required this.businessDate,
    required this.feedKg,
    required this.eggsCount,
    this.pendingLocal = false,
  });
}

class DailyHistoryViewModel extends ChangeNotifier {
  final CacheRepository cache;
  List<DailyHistoryRow> _rows = [];
  JsonObject _query = const {};
  bool _isLoading = false;

  DailyHistoryViewModel({required this.cache});

  List<DailyHistoryRow> get rows => _rows;
  JsonObject get query => _query;
  bool get isLoading => _isLoading;

  Future<void> filter(JsonObject query) async {
    _isLoading = true;
    _query = query;
    notifyListeners();

    try {
      final accepted = await cache.list('daily');

      final cageId = query['cage_id'] as String?;
      final date = query['date'] as String?;
      final from = query['from'] as String?;
      final to = query['to'] as String?;

      _rows = accepted.where((raw) {
        if (cageId != null && raw['cage_id'] != cageId) return false;
        final bd = raw['business_date'] as String?;
        if (date != null && bd != date) return false;
        if (from != null && (bd ?? '') .compareTo(from) < 0) return false;
        if (to != null && (bd ?? '').compareTo(to) > 0) return false;
        return true;
      }).map((raw) {
        return DailyHistoryRow(
          id: raw['id'] as String? ?? '',
          cageId: raw['cage_id'] as String? ?? '',
          businessDate: raw['business_date'] as String? ?? '',
          feedKg: raw['feed_kg'] as String? ?? '0.00',
          eggsCount: (raw['eggs_count'] as num?)?.toInt() ?? 0,
          pendingLocal: false,
        );
      }).toList()
        ..sort((a, b) => b.businessDate.compareTo(a.businessDate));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
