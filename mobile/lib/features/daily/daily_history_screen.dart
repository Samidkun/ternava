import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'daily_history_view_model.dart';

class DailyHistoryScreen extends StatefulWidget {
  final DailyHistoryViewModel viewModel;

  const DailyHistoryScreen({super.key, required this.viewModel});

  @override
  State<DailyHistoryScreen> createState() => _DailyHistoryScreenState();
}

class _DailyHistoryScreenState extends State<DailyHistoryScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.viewModel.rows.isEmpty && widget.viewModel.query.isEmpty) {
      widget.viewModel.filter(const {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        return Scaffold(
          backgroundColor: TernavaTheme.canvas,
          appBar: AppBar(
            title: const Text('Riwayat Catatan'),
            backgroundColor: TernavaTheme.surface,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: TernavaTheme.border, height: 1),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter: Kandang & Tanggal',
                        style: TextStyle(
                          fontSize: 13,
                          color: TernavaTheme.textMuted,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.filter_alt_outlined, size: 18),
                      label: const Text('Ubah'),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              Expanded(
                child: vm.rows.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada catatan pada rentang ini.',
                          style: TextStyle(color: TernavaTheme.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: vm.rows.length,
                        itemBuilder: (context, index) {
                          final row = vm.rows[index];
                          return Card(
                            elevation: 0,
                            color: TernavaTheme.surface,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                color: TernavaTheme.border,
                              ),
                            ),
                            child: ListTile(
                              title: Text(
                                row.businessDate,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: TernavaTheme.textDark,
                                ),
                              ),
                              subtitle: Text(
                                'Pakan: ${row.feedKg} kg · Telur: ${row.eggsCount} butir',
                                style: const TextStyle(
                                  color: TernavaTheme.textMuted,
                                ),
                              ),
                              trailing: row.pendingLocal
                                  ? const Chip(
                                      label: Text(
                                        'Lokal',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: Color(0xFFFFF3E0),
                                    )
                                  : const Icon(
                                      Icons.verified,
                                      color: TernavaTheme.success,
                                      size: 20,
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
