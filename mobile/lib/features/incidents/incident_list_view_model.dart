import 'package:flutter/foundation.dart';

import '../../core/api/generated/types.dart';
import '../../core/sync/cache_repository.dart';

class IncidentRow {
  final String id;
  final String cageId;
  final String observation;
  final String attention;
  final String status;
  final String? assigneeId;
  final String observedAt;

  const IncidentRow({
    required this.id,
    required this.cageId,
    required this.observation,
    required this.attention,
    required this.status,
    required this.assigneeId,
    required this.observedAt,
  });

  /// The farm display string for the UTC observation timestamp.
  String displayObservedAt() {
    final parsed = DateTime.tryParse(observedAt);
    if (parsed == null) return observedAt;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class IncidentListViewModel extends ChangeNotifier {
  final CacheRepository cache;

  List<IncidentRow> _rows = [];
  JsonObject _query = const {};
  bool _isLoading = false;

  IncidentListViewModel({required this.cache});

  List<IncidentRow> get rows => _rows;
  JsonObject get query => _query;
  bool get isLoading => _isLoading;

  Future<void> filter(JsonObject query) async {
    _isLoading = true;
    _query = query;
    notifyListeners();

    try {
      final accepted = await cache.list('incident');

      final status = query['status'] as String?;
      final cageId = query['cage_id'] as String?;
      final assigned = query['assigned'] as String?;

      _rows =
          accepted
              .where((raw) {
                if (status != null && raw['status'] != status) return false;
                if (cageId != null && raw['cage_id'] != cageId) return false;
                if (assigned == 'unassigned' && raw['assignee_id'] != null) {
                  return false;
                }
                if (assigned == 'assigned' && raw['assignee_id'] == null) {
                  return false;
                }
                return true;
              })
              .map((raw) {
                return IncidentRow(
                  id: raw['id'] as String? ?? '',
                  cageId: raw['cage_id'] as String? ?? '',
                  observation: raw['observation'] as String? ?? '',
                  attention: raw['attention'] as String? ?? 'routine',
                  status: raw['status'] as String? ?? 'open',
                  assigneeId: raw['assignee_id'] as String?,
                  observedAt: raw['observed_at'] as String? ?? '',
                );
              })
              .toList()
            ..sort((a, b) => b.observedAt.compareTo(a.observedAt));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
