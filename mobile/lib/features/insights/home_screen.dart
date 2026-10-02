import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'home_view_model.dart';

/// The owner/admin home: today's completeness at a glance, with an explicit
/// as-of marker and a stale banner when the snapshot could not be refreshed.
class HomeScreen extends StatefulWidget {
  final HomeViewModel viewModel;

  const HomeScreen({super.key, required this.viewModel});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.viewModel.dashboard == null) {
      widget.viewModel.refresh(DateTime.now().toIso8601String().substring(0, 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final dash = vm.dashboard;

        return Scaffold(
          backgroundColor: TernavaTheme.canvas,
          appBar: AppBar(
            title: const Text('Ringkasan Hari Ini'),
            backgroundColor: TernavaTheme.surface,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: TernavaTheme.border, height: 1),
            ),
          ),
          body: dash == null
              ? Center(
                  child: vm.isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          vm.errorMessage ?? 'Ringkasan belum tersedia.',
                          style: const TextStyle(color: TernavaTheme.textMuted),
                        ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      dash.businessDate,
                      style: const TextStyle(
                        fontSize: 13,
                        color: TernavaTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Snapshot per ${dash.asOf} (${dash.timezone})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: TernavaTheme.textMuted,
                      ),
                    ),
                    if (vm.isStale) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TernavaTheme.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Data mungkin tertunda — tidak dapat memuat ulang.',
                          style: TextStyle(color: TernavaTheme.warning),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _card(
                      title: 'Kelengkapan',
                      child: Text(
                        '${dash.acceptedRecords} dari ${dash.expectedRecords} '
                        'ternak tercatat'
                        '${dash.pendingRecords > 0 ? ' · ${dash.pendingRecords} belum' : ''}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: TernavaTheme.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      title: 'Produksi',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dash.eggsLabel,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: TernavaTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dash.feedKg == null
                                ? 'Pakan: Belum dicatat'
                                : 'Pakan: ${dash.feedKg} kg',
                            style: const TextStyle(
                              fontSize: 13,
                              color: TernavaTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      title: 'Perhatian',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${dash.openIncidents} temuan terbuka',
                            style: const TextStyle(
                              fontSize: 15,
                              color: TernavaTheme.textDark,
                            ),
                          ),
                          if (dash.lowStockFeedTypeIds.isNotEmpty)
                            Text(
                              '${dash.lowStockFeedTypeIds.length} jenis pakan di bawah minimum',
                              style: const TextStyle(
                                fontSize: 13,
                                color: TernavaTheme.warning,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      title: 'Status Kandang',
                      child: Column(
                        children: [
                          for (final cage in dash.cages)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      cage.cageId,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: TernavaTheme.textDark,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    cage.eggsLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cage.isAccepted
                                          ? TernavaTheme.success
                                          : TernavaTheme.textMuted,
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

  Widget _card({required String title, required Widget child}) {
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
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TernavaTheme.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
