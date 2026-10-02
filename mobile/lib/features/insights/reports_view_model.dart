import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/types.dart';

/// One row of the operations report. A `missing` row carries no figures and
/// must be rendered as "not recorded", never as a zero.
class ReportRowView {
  final String businessDate;
  final String cageId;
  final String flockId;
  final String recordState;
  final int? eggsCount;
  final String? feedKg;
  final int? mortalityCount;
  final String? condition;

  const ReportRowView({
    required this.businessDate,
    required this.cageId,
    required this.flockId,
    required this.recordState,
    required this.eggsCount,
    required this.feedKg,
    required this.mortalityCount,
    required this.condition,
  });

  bool get isMissing => recordState == 'missing';
  bool get isAccepted => recordState == 'accepted';

  String get eggsLabel =>
      eggsCount == null ? 'Belum dicatat' : '$eggsCount butir';
  String get feedLabel => feedKg == null ? 'Belum dicatat' : '$feedKg kg';

  factory ReportRowView.fromJson(JsonObject json) => ReportRowView(
    businessDate: json['business_date'] as String? ?? '',
    cageId: json['cage_id'] as String? ?? '',
    flockId: json['flock_id'] as String? ?? '',
    recordState: json['record_state'] as String? ?? 'missing',
    eggsCount: (json['eggs_count'] as num?)?.toInt(),
    feedKg: json['feed_kg'] as String?,
    mortalityCount: (json['mortality_count'] as num?)?.toInt(),
    condition: json['condition'] as String?,
  );
}

class OperationsReport {
  final String from;
  final String to;
  final String timezone;
  final String asOf;
  final int expectedRecords;
  final int acceptedRecords;
  final int? eggsCount;
  final String? feedKg;
  final List<ReportRowView> rows;

  const OperationsReport({
    required this.from,
    required this.to,
    required this.timezone,
    required this.asOf,
    required this.expectedRecords,
    required this.acceptedRecords,
    required this.eggsCount,
    required this.feedKg,
    required this.rows,
  });

  /// When nothing was accepted the total is unknown, not zero.
  String get eggsLabel =>
      eggsCount == null ? 'Belum dicatat' : '$eggsCount butir';
  String get feedLabel => feedKg == null ? 'Belum dicatat' : '$feedKg kg';

  factory OperationsReport.fromJson(JsonObject json) => OperationsReport(
    from: json['from'] as String? ?? '',
    to: json['to'] as String? ?? '',
    timezone: json['timezone'] as String? ?? 'UTC',
    asOf: json['as_of'] as String? ?? '',
    expectedRecords: (json['expected_records'] as num?)?.toInt() ?? 0,
    acceptedRecords: (json['accepted_records'] as num?)?.toInt() ?? 0,
    eggsCount: (json['eggs_count'] as num?)?.toInt(),
    feedKg: json['feed_kg'] as String?,
    rows: ((json['rows'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map((raw) => ReportRowView.fromJson(Map<String, Object?>.from(raw)))
        .toList(),
  );
}

class ReportsViewModel extends ChangeNotifier {
  static const int maxDays = 183;

  final ApiClient apiClient;

  OperationsReport? _report;
  String _from = '';
  String _to = '';
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;

  ReportsViewModel({required this.apiClient});

  OperationsReport? get report => _report;
  String get from => _from;
  String get to => _to;
  bool get isLoading => _isLoading;
  bool get isExporting => _isExporting;
  String? get errorMessage => _errorMessage;

  /// Returns true when the report was loaded. An invalid period is rejected
  /// locally, before any request, so the server never sees it.
  Future<bool> load(String from, String to) async {
    _errorMessage = null;

    if (!_isValidPeriod(from, to)) {
      _errorMessage =
          'Rentang tanggal maksimal $maxDays hari dan tidak boleh terbalik.';
      notifyListeners();
      return false;
    }

    _from = from;
    _to = to;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await apiClient.request(
        'operationsReport',
        queryParams: {'from': from, 'to': to},
      );
      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw const ApiFailure(
          code: 'INVALID_RESPONSE',
          message: 'Laporan tidak tersedia.',
          status: 0,
        );
      }
      _report = OperationsReport.fromJson(Map<String, Object?>.from(data));
      return true;
    } on ApiFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Requests the server-rendered CSV. The active filters are preserved even
  /// when the export fails, so the user can retry without re-selecting dates.
  Future<void> exportCsv() async {
    _isExporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await apiClient.request(
        'exportReport',
        queryParams: {'from': _from, 'to': _to},
      );
    } on ApiFailure catch (e) {
      _errorMessage = e.message;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  bool _isValidPeriod(String from, String to) {
    final fromDate = DateTime.tryParse(from);
    final toDate = DateTime.tryParse(to);
    if (fromDate == null || toDate == null) return false;
    if (toDate.isBefore(fromDate)) return false;
    return toDate.difference(fromDate).inDays + 1 <= maxDays;
  }
}
