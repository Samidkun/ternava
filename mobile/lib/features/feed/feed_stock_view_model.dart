import 'package:flutter/foundation.dart';

import '../../core/sync/cache_repository.dart';

class FeedStockItem {
  final String feedTypeId;
  final String feedTypeName;
  final String balanceKg;
  final String? asOf;

  const FeedStockItem({
    required this.feedTypeId,
    required this.feedTypeName,
    required this.balanceKg,
    this.asOf,
  });
}

class FeedStockViewModel extends ChangeNotifier {
  final CacheRepository cache;

  List<FeedStockItem> _items = [];
  String? _asOf;
  bool _isLoading = false;

  FeedStockViewModel({required this.cache});

  List<FeedStockItem> get items => _items;
  String? get asOf => _asOf;
  bool get isLoading => _isLoading;

  /// True when the cached snapshot is older than one sync cycle, so the
  /// operator must be told the numbers may be stale.
  bool get isStale {
    final asOf = _asOf;
    if (asOf == null) return true;
    final parsed = DateTime.tryParse(asOf);
    if (parsed == null) return true;
    return DateTime.now().toUtc().difference(parsed.toUtc()).inMinutes > 15;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final balances = await cache.list('feed_balance');
      _items = balances.map((b) {
        return FeedStockItem(
          feedTypeId: b['feed_type_id'] as String? ?? '',
          feedTypeName: b['feed_type_name'] as String? ??
              b['feed_type_id'] as String? ??
              'Pakan',
          balanceKg: '${b['balance_kg'] ?? '0.00'}',
          asOf: b['as_of'] as String?,
        );
      }).toList();

      final checkpoint = await cache.getCheckpoint();
      _asOf = checkpoint?.asOf ?? (balances.isNotEmpty
          ? balances.first['as_of'] as String?
          : null);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
