import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'farm_setup_view_model.dart';

class FarmSetupScreen extends StatefulWidget {
  final FarmSetupViewModel viewModel;

  const FarmSetupScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<FarmSetupScreen> createState() => _FarmSetupScreenState();
}

class _FarmSetupScreenState extends State<FarmSetupScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _timezoneController = TextEditingController(text: 'Asia/Jakarta');

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _timezoneController.dispose();
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
            title: const Text('Setup Peternakan'),
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
              const Text(
                'Isi data peternakan Anda. Zona waktu tidak dapat diubah setelah ada operasi tercatat.',
                style: TextStyle(fontSize: 13, color: TernavaTheme.textMuted),
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
                  child: Text(
                    vm.errorMessage!,
                    style: const TextStyle(
                        color: TernavaTheme.error, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const Key('farm-name'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Peternakan',
                  hintText: 'misal: Peternakan Sumber Rejeki',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('farm-location'),
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Lokasi',
                  hintText: 'misal: Blitar, Jawa Timur',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('farm-timezone'),
                controller: _timezoneController,
                decoration: const InputDecoration(
                  labelText: 'Zona Waktu',
                  hintText: 'misal: Asia/Jakarta',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: vm.isSaving
                    ? null
                    : () async {
                        final ok = await vm.save({
                          'name': _nameController.text.trim(),
                          'location': _locationController.text.trim(),
                          'timezone': _timezoneController.text.trim(),
                        });
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Peternakan berhasil disimpan.')),
                          );
                        }
                      },
                child: vm.isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan peternakan'),
              ),
            ],
          ),
        );
      },
    );
  }
}
