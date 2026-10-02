import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'daily_form_view_model.dart';

class DailyFormScreen extends StatefulWidget {
  final DailyFormViewModel viewModel;

  const DailyFormScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<DailyFormScreen> createState() => _DailyFormScreenState();
}

class _DailyFormScreenState extends State<DailyFormScreen> {
  final _feedController = TextEditingController();
  final _eggsController = TextEditingController();
  final _mortalityController = TextEditingController();
  final _notesController = TextEditingController();
  String _condition = 'normal';

  @override
  void dispose() {
    _feedController.dispose();
    _eggsController.dispose();
    _mortalityController.dispose();
    _notesController.dispose();
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
            title: Text('Catatan ${vm.cageName}'),
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
              Text(
                'Tanggal usaha: ${vm.businessDate}',
                style: const TextStyle(
                  fontSize: 14,
                  color: TernavaTheme.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              if (vm.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TernavaTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: TernavaTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: TernavaTheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vm.errorMessage!,
                          style: const TextStyle(
                            color: TernavaTheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const Key('feed-kg-input'),
                controller: _feedController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Jumlah Pakan (kg)',
                  hintText: 'misal: 12.50',
                  helperText: 'Wajib diisi, dua angka desimal.',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('eggs-input'),
                controller: _eggsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Telur (butir)',
                  hintText: 'misal: 320',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('mortality-input'),
                controller: _mortalityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ayam Mati (ekor, opsional)',
                  hintText: 'Kosongkan jika tidak diperiksa',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: const Key('condition-input'),
                initialValue: _condition,
                decoration: const InputDecoration(
                  labelText: 'Kondisi Kandang',
                ),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(
                      value: 'perlu_perhatian',
                      child: Text('Perlu Perhatian')),
                  DropdownMenuItem(value: 'kritis', child: Text('Kritis')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _condition = val);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('notes-input'),
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan Tambahan (opsional)',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: vm.isSaving
                    ? null
                    : () async {
                        final ok = await vm.submit(
                          feedKgText: _feedController.text,
                          eggsCountText: _eggsController.text,
                          mortalityCountText: _mortalityController.text,
                          condition: _condition,
                          notes: _notesController.text.trim().isEmpty
                              ? null
                              : _notesController.text.trim(),
                        );
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Catatan tersimpan lokal, menunggu sinkronisasi.'),
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      },
                child: vm.isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Kirim Catatan'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: vm.isSaving
                    ? null
                    : () async {
                        await vm.saveDraft(
                          feedKgText: _feedController.text,
                          eggsCountText: _eggsController.text,
                          notes: _notesController.text.trim().isEmpty
                              ? null
                              : _notesController.text.trim(),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Draf lokal disimpan.')),
                          );
                        }
                      },
                child: const Text('Simpan Draf'),
              ),
            ],
          ),
        );
      },
    );
  }
}
