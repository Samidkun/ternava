import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'flock_form_view_model.dart';

class FlockFormScreen extends StatefulWidget {
  final FlockFormViewModel viewModel;

  const FlockFormScreen({super.key, required this.viewModel});

  @override
  State<FlockFormScreen> createState() => _FlockFormScreenState();
}

class _FlockFormScreenState extends State<FlockFormScreen> {
  final _nameController = TextEditingController();
  final _populationController = TextEditingController();
  final _startDateController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final init = widget.viewModel.initial;
    if (init != null) {
      _nameController.text = init['name'] as String? ?? '';
      _populationController.text = '${init['initial_population'] ?? ''}';
      _startDateController.text = init['start_date'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _populationController.dispose();
    _startDateController.dispose();
    _reasonController.dispose();
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
            title: Text(vm.edit ? 'Ubah Kelompok' : 'Kelompok Baru'),
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
                      color: TernavaTheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    vm.errorMessage!,
                    style: const TextStyle(
                      color: TernavaTheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const Key('flock-name'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Kelompok'),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('initial-population'),
                controller: _populationController,
                enabled: !vm.initialPopulationLocked,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Populasi Awal (ekor)',
                  helperText: vm.initialPopulationLocked
                      ? 'Tidak dapat diubah setelah ada catatan operasi.'
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('start-date'),
                controller: _startDateController,
                enabled: !vm.edit,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Mulai',
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              if (vm.edit) ...[
                const SizedBox(height: 14),
                TextField(
                  key: const Key('change-reason'),
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Alasan Perubahan',
                    helperText: 'Wajib diisi untuk audit perubahan.',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: vm.isSaving
                    ? null
                    : () async {
                        final ok = await vm.save({
                          'name': _nameController.text.trim(),
                          if (!vm.initialPopulationLocked)
                            'initial_population': int.tryParse(
                              _populationController.text.trim(),
                            ),
                          if (!vm.edit)
                            'start_date': _startDateController.text.trim(),
                        }, reason: _reasonController.text);
                        if (ok && context.mounted) {
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
                    : const Text('Simpan kelompok'),
              ),
            ],
          ),
        );
      },
    );
  }
}
