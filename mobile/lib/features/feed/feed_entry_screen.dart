import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'feed_entry_view_model.dart';

class FeedEntryScreen extends StatefulWidget {
  final FeedEntryViewModel viewModel;

  const FeedEntryScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<FeedEntryScreen> createState() => _FeedEntryScreenState();
}

class _FeedEntryScreenState extends State<FeedEntryScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _kind = 'in';

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
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
            title: const Text('Transaksi Pakan'),
            backgroundColor: TernavaTheme.surface,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: TernavaTheme.border, height: 1),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (vm.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TernavaTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: TernavaTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    vm.errorMessage!,
                    style: const TextStyle(
                        color: TernavaTheme.error, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'in', label: Text('Masuk')),
                  ButtonSegment(value: 'out', label: Text('Keluar')),
                ],
                selected: {_kind},
                onSelectionChanged: (sel) =>
                    setState(() => _kind = sel.first),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('feed-amount'),
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Jumlah (kg)',
                  hintText: 'misal: 25.50',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('feed-note'),
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: vm.isSaving
                    ? null
                    : () async {
                        final ok = await vm.save(
                          feedTypeId: '',
                          kind: _kind,
                          amountKg: _amountController.text,
                          note: _noteController.text,
                        );
                        if (ok && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                child: vm.isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan transaksi'),
              ),
            ],
          ),
        );
      },
    );
  }
}
