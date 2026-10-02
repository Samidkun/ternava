import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'feed_type_form_view_model.dart';

class FeedTypeFormScreen extends StatefulWidget {
  final FeedTypeFormViewModel viewModel;

  const FeedTypeFormScreen({super.key, required this.viewModel});

  @override
  State<FeedTypeFormScreen> createState() => _FeedTypeFormScreenState();
}

class _FeedTypeFormScreenState extends State<FeedTypeFormScreen> {
  final _nameController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _reasonController = TextEditingController();
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    final init = widget.viewModel.initial;
    if (init != null) {
      _nameController.text = init['name'] as String? ?? '';
      _thresholdController.text = '${init['min_threshold_kg'] ?? ''}';
      _status = init['status'] as String? ?? 'active';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _thresholdController.dispose();
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
            title: Text(vm.edit ? 'Ubah Jenis Pakan' : 'Jenis Pakan Baru'),
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
                key: const Key('feed-type-name'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Jenis Pakan',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('min-threshold'),
                controller: _thresholdController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Ambang Minimum (kg)',
                  helperText:
                      'Peringatan muncul saat saldo turun melewati ambang ini.',
                ),
              ),
              if (vm.edit) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('feed-type-status'),
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Aktif')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Nonaktif'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'active'),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('change-reason'),
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Alasan Perubahan',
                    helperText: 'Wajib untuk audit perubahan.',
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
                          'min_threshold_kg': _thresholdController.text.trim(),
                          if (vm.edit) 'status': _status,
                          if (vm.edit &&
                              _reasonController.text.trim().isNotEmpty)
                            'reason': _reasonController.text.trim(),
                        });
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
                    : const Text('Simpan jenis pakan'),
              ),
            ],
          ),
        );
      },
    );
  }
}
