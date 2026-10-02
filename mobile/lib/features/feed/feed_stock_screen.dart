import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'feed_stock_view_model.dart';

class FeedStockScreen extends StatefulWidget {
  final FeedStockViewModel viewModel;

  const FeedStockScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<FeedStockScreen> createState() => _FeedStockScreenState();
}

class _FeedStockScreenState extends State<FeedStockScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  String _formatAsOf(String? iso) {
    if (iso == null) return '-';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} ${two(local.hour)}:${two(local.minute)}';
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
            title: const Text('Saldo Pakan'),
            backgroundColor: TernavaTheme.surface,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: TernavaTheme.border, height: 1),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: TernavaTheme.primary,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.of(context).pushNamed('/feed-entry'),
            icon: const Icon(Icons.add),
            label: const Text('Transaksi Pakan'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vm.isStale)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: TernavaTheme.warning.withValues(alpha: 0.12),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_outlined,
                          size: 18, color: TernavaTheme.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Angka mungkin belum terbaru. Terakhir diperbarui ${_formatAsOf(vm.asOf)}.',
                          style: const TextStyle(
                              color: TernavaTheme.textDark, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: vm.items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Belum ada data saldo pakan. Lakukan sinkronisasi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: TernavaTheme.textMuted),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: vm.items.length,
                        itemBuilder: (context, index) {
                          final item = vm.items[index];
                          return Card(
                            elevation: 0,
                            color: TernavaTheme.surface,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: TernavaTheme.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Color(0xFFE8F0ED),
                                    child: Icon(Icons.grain,
                                        color: TernavaTheme.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.feedTypeName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: TernavaTheme.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Terakhir diperbarui ${_formatAsOf(item.asOf ?? vm.asOf)}',
                                          style: const TextStyle(
                                              color: TernavaTheme.textMuted,
                                              fontSize: 12),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${item.balanceKg} kg',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: TernavaTheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
