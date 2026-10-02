import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'reports_view_model.dart';

/// The operations report with a period selector, an export action and rows
/// that distinguish "not recorded" from a genuine zero.
class ReportsScreen extends StatefulWidget {
  final ReportsViewModel viewModel;

  const ReportsScreen({super.key, required this.viewModel});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final report = vm.report;

        return Scaffold(
          backgroundColor: TernavaTheme.canvas,
          appBar: AppBar(
            title: const Text('Laporan'),
            backgroundColor: TernavaTheme.surface,
            elevation: 0,
            actions: [
              TextButton(
                key: const Key('report-export'),
                onPressed: vm.isExporting ? null : () => vm.exportCsv(),
                child: vm.isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Ekspor CSV'),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: TernavaTheme.border, height: 1),
            ),
          ),
          body: Column(
            children: [
              if (vm.errorMessage != null)
                Container(
                  width: double.infinity,
                  color: TernavaTheme.error.withValues(alpha: 0.10),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    vm.errorMessage!,
                    style: const TextStyle(color: TernavaTheme.error),
                  ),
                ),
              if (vm.from.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        '${vm.from} → ${vm.to}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: TernavaTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: report == null
                    ? Center(
                        child: vm.isLoading
                            ? const CircularProgressIndicator()
                            : const Text(
                                'Pilih periode untuk melihat laporan.',
                                style: TextStyle(color: TernavaTheme.textMuted),
                              ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _summary(report),
                          const SizedBox(height: 12),
                          for (final row in report.rows)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: TernavaTheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: TernavaTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${row.businessDate} · ${row.cageId}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: TernavaTheme.textDark,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        row.isAccepted
                                            ? 'Tercatat'
                                            : 'Belum dicatat',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: row.isAccepted
                                              ? TernavaTheme.success
                                              : TernavaTheme.warning,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${row.eggsLabel} · ${row.feedLabel}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: TernavaTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summary(OperationsReport report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TernavaTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TernavaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan (${report.timezone})',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TernavaTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.eggsLabel,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: TernavaTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pakan: ${report.feedLabel}',
            style: const TextStyle(fontSize: 13, color: TernavaTheme.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            '${report.acceptedRecords} dari ${report.expectedRecords} ternak tercatat',
            style: const TextStyle(fontSize: 13, color: TernavaTheme.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Snapshot per ${report.asOf}',
            style: const TextStyle(fontSize: 11, color: TernavaTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
