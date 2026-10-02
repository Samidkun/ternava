import 'package:flutter/foundation.dart';

import '../../core/api/generated/types.dart';
import '../../core/sync/cache_repository.dart';

class CageListViewModel extends ChangeNotifier {
  final CacheRepository cache;
  final Set<String>? assignedCageIds;

  List<JsonObject> _cages = [];
  bool _isLoading = false;

  CageListViewModel({required this.cache, this.assignedCageIds});

  List<JsonObject> get cages => _cages;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await cache.listAssignedCages(assignedIds: assignedCageIds);
      _cages = rows
        ..sort(
          (a, b) => (a['code'] as String? ?? '').compareTo(
            b['code'] as String? ?? '',
          ),
        );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
