import 'package:flutter/foundation.dart';

import '../../core/sync/cache_repository.dart';

class TodayCageItem {
  final String id;
  final String code;
  final String name;
  final bool hasRecordedToday;

  const TodayCageItem({
    required this.id,
    required this.code,
    required this.name,
    this.hasRecordedToday = false,
  });
}

class TodayViewModel extends ChangeNotifier {
  final CacheRepository cache;
  List<TodayCageItem> _cages = [];
  bool _isLoading = false;

  TodayViewModel({required this.cache});

  List<TodayCageItem> get cages => _cages;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final rawCages = await cache.list('cage');
      _cages = rawCages.map((raw) {
        return TodayCageItem(
          id: raw['id'] as String? ?? '',
          code: raw['code'] as String? ?? '',
          name: raw['name'] as String? ?? 'Kandang',
          hasRecordedToday: false,
        );
      }).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
