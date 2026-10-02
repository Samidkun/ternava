import 'package:flutter/foundation.dart';

import '../../core/api/generated/types.dart';
import '../../core/sync/cache_repository.dart';

class FlockListViewModel extends ChangeNotifier {
  final CacheRepository cache;

  List<JsonObject> _flocks = [];
  String _statusFilter = 'active';
  bool _isLoading = false;

  FlockListViewModel({required this.cache});

  List<JsonObject> get flocks => _flocks;
  String get statusFilter => _statusFilter;
  bool get isLoading => _isLoading;

  Future<void> filter(String status) async {
    _isLoading = true;
    _statusFilter = status;
    notifyListeners();

    try {
      final all = await cache.list('flock');
      _flocks = all.where((f) {
        final s = f['status'] as String? ?? 'active';
        return s == status;
      }).toList()
        ..sort((a, b) => (b['start_date'] as String? ?? '')
            .compareTo(a['start_date'] as String? ?? ''));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
