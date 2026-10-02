import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/types.dart';

/// A single cage's completeness state on the dashboard.
class CageStatusRow {
  final String cageId;
  final String? flockId;
  final String recordState;
  final int? eggsCount;
  final String? feedKg;

  const CageStatusRow({
    required this.cageId,
    required this.flockId,
    required this.recordState,
    required this.eggsCount,
    required this.feedKg,
  });

  bool get isMissing => recordState == 'missing';
  bool get isNotExpected => recordState == 'not_expected';
  bool get isAccepted => recordState == 'accepted';

  /// A missing or not-expected cage has no egg figure; it must never be shown
  /// as zero, because zero would be a false claim about the day's production.
  String get eggsLabel => eggsCount == null ? 'Belum dicatat' : '$eggsCount butir';

  factory CageStatusRow.fromJson(JsonObject json) => CageStatusRow(
        cageId: json['cage_id'] as String? ?? '',
        flockId: json['flock_id'] as String?,
        recordState: json['record_state'] as String? ?? 'not_expected',
        eggsCount: (json['eggs_count'] as num?)?.toInt(),
        feedKg: json['feed_kg'] as String?,
      );
}

/// An immutable snapshot of the dashboard, kept with its as-of timestamp so
/// the UI can label a cached view honestly.
class DashboardSnapshot {
  final String businessDate;
  final String timezone;
  final String asOf;
  final int expectedRecords;
  final int acceptedRecords;
  final int? eggsCount;
  final String? feedKg;
  final int openIncidents;
  final List<String> lowStockFeedTypeIds;
  final List<CageStatusRow> cages;

  const DashboardSnapshot({
    required this.businessDate,
    required this.timezone,
    required this.asOf,
    required this.expectedRecords,
    required this.acceptedRecords,
    required this.eggsCount,
    required this.feedKg,
    required this.openIncidents,
    required this.lowStockFeedTypeIds,
    required this.cages,
  });

  int get pendingRecords => expectedRecords - acceptedRecords;
  bool get isComplete => expectedRecords > 0 && acceptedRecords == expectedRecords;

  String get eggsLabel => eggsCount == null ? 'Belum dicatat' : '$eggsCount butir';

  factory DashboardSnapshot.fromJson(JsonObject json) => DashboardSnapshot(
        businessDate: json['business_date'] as String? ?? '',
        timezone: json['timezone'] as String? ?? 'UTC',
        asOf: json['as_of'] as String? ?? '',
        expectedRecords: (json['expected_records'] as num?)?.toInt() ?? 0,
        acceptedRecords: (json['accepted_records'] as num?)?.toInt() ?? 0,
        eggsCount: (json['eggs_count'] as num?)?.toInt(),
        feedKg: json['feed_kg'] as String?,
        openIncidents: (json['open_incidents'] as num?)?.toInt() ?? 0,
        lowStockFeedTypeIds:
            ((json['low_stock_feed_type_ids'] as List<dynamic>?) ?? [])
                .map((e) => e.toString())
                .toList(),
        cages: ((json['cages'] as List<dynamic>?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map((raw) => CageStatusRow.fromJson(Map<String, Object?>.from(raw)))
            .toList(),
      );
}

class HomeViewModel extends ChangeNotifier {
  final ApiClient apiClient;

  DashboardSnapshot? _dashboard;
  bool _isLoading = false;
  bool _isStale = false;
  String? _errorMessage;

  HomeViewModel({required this.apiClient});

  DashboardSnapshot? get dashboard => _dashboard;
  bool get isLoading => _isLoading;

  /// True when the shown snapshot could not be refreshed and is being served
  /// from the last successful load.
  bool get isStale => _isStale;
  String? get errorMessage => _errorMessage;

  Future<void> refresh(String businessDate) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await apiClient.request(
        'dashboard',
        queryParams: {'business_date': businessDate},
      );
      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw const ApiFailure(
          code: 'INVALID_RESPONSE',
          message: 'Ringkasan tidak tersedia.',
          status: 0,
        );
      }
      _dashboard = DashboardSnapshot.fromJson(Map<String, Object?>.from(data));
      _isStale = false;
    } on ApiFailure catch (e) {
      // Keep the previous snapshot but flag it as stale; never clear it, so an
      // offline owner still sees the last known figure with an explicit caveat.
      _isStale = _dashboard != null;
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
