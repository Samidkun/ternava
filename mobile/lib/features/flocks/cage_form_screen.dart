import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'cage_form_view_model.dart';

class CageFormScreen extends StatefulWidget {
  final CageFormViewModel viewModel;
  final bool edit;
  final Map<String, dynamic>? initial;

  const CageFormScreen({
    super.key,
    required this.viewModel,
    this.edit = false,
    this.initial,
  });

  @override
  State<CageFormScreen> createState() => _CageFormScreenState();
}

class _CageFormScreenState extends State<CageFormScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _codeController.text = init['code'] as String? ?? '';
      _nameController.text = init['name'] as String? ?? '';
      _locationController.text = init['location'] as String? ?? '';
      _notesController.text = init['notes'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _locationController.dispose();
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
            title: Text(widget.edit ? 'Ubah Kandang' : 'Kandang Baru'),
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
                key: const Key('cage-code'),
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Kode Kandang',
                  hintText: 'misal: K-01',
                  errorText: vm.fieldErrors['code'],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('cage-name'),
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Kandang',
                  hintText: 'misal: Kandang Baterai A',
                  errorText: vm.fieldErrors['name'],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('cage-location'),
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Lokasi (opsional)',
                  errorText: vm.fieldErrors['location'],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('cage-notes'),
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Keterangan (opsional)',
                  errorText: vm.fieldErrors['notes'],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: vm.isSaving
                    ? null
                    : () async {
                        final ok = await vm.save(
                          {
                            'code': _codeController.text.trim(),
                            'name': _nameController.text.trim(),
                            'location': _locationController.text.trim(),
                            'notes': _notesController.text.trim(),
                          },
                          edit: widget.edit,
                          id: widget.initial?['id'] as String?,
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan kandang'),
              ),
            ],
          ),
        );
      },
    );
  }
}
