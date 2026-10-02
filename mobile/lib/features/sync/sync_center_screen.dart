import 'package:flutter/material.dart';

import '../../core/sync/outbox_repository.dart';
import '../../ui/theme/ternava_theme.dart';
import 'sync_center_view_model.dart';

class SyncCenterScreen extends StatefulWidget {
  final SyncCenterViewModel viewModel;

  const SyncCenterScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  String _stateLabel(IntentState state) {
    switch (state) {
      case IntentState.pending:
        return 'Menunggu dikirim';
      case IntentState.sending:
        return 'Sedang dikirim';
      case IntentState.accepted:
        return 'Terkirim';
      case IntentState.failed:
        return 'Gagal';
      case IntentState.needsReview:
        return 'Perlu ditinjau';
    }
  }

  Color _stateColor(IntentState state) {
    switch (state) {
      case IntentState.accepted:
        return TernavaTheme.success;
      case IntentState.needsReview:
      case IntentState.failed:
        return TernavaTheme.error;
      default:
        return TernavaTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final reviewCount = vm.items
            .where((i) => i.state == IntentState.needsReview)
            .length;

        return Scaffold(
          backgroundColor: TernavaTheme.canvas,
          appBar: AppBar(
            title: const Text('Pusat Sinkronisasi'),
            backgroundColor: TernavaTheme.surface,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Perbarui',
                onPressed: vm.isBusy ? null : vm.load,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: TernavaTheme.border, height: 1),
            ),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: reviewCount > 0
                    ? TernavaTheme.error.withValues(alpha: 0.08)
                    : TernavaTheme.surface,
                child: Row(
                  children: [
                    Icon(
                      reviewCount > 0
                          ? Icons.warning_amber_rounded
                          : Icons.cloud_done_outlined,
                      color: reviewCount > 0
                          ? TernavaTheme.error
                          : TernavaTheme.success,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reviewCount > 0
                            ? '$reviewCount catatan perlu ditinjau sebelum dikirim.'
                            : 'Semua catatan lokal sudah tersinkronisasi.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: reviewCount > 0
                              ? TernavaTheme.error
                              : TernavaTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: vm.items.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada antrean sinkronisasi.',
                          style: TextStyle(color: TernavaTheme.textMuted),
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
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.operationId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: TernavaTheme.textDark,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _stateColor(item.state)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _stateLabel(item.state),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _stateColor(item.state),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Kunci: ${item.id}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: TernavaTheme.textMuted,
                                    ),
                                  ),
                                  if (item.lastError != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.lastError!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: TernavaTheme.error,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: vm.isBusy
                                            ? null
                                            : () => vm.cancelDraft(item.id,
                                                confirmed: true),
                                        child: const Text('Batalkan draf'),
                                      ),
                                      const SizedBox(width: 6),
                                      FilledButton(
                                        onPressed: vm.isBusy
                                            ? null
                                            : () => vm.retry(item.id),
                                        child: const Text('Coba lagi'),
                                      ),
                                    ],
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
