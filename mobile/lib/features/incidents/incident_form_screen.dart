import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'incident_form_view_model.dart';

class IncidentFormScreen extends StatefulWidget {
  final IncidentFormViewModel viewModel;

  const IncidentFormScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<IncidentFormScreen> createState() => _IncidentFormScreenState();
}

class _IncidentFormScreenState extends State<IncidentFormScreen> {
  final _observationController = TextEditingController();
  String _attention = 'routine';

  @override
  void dispose() {
    _observationController.dispose();
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
            title: const Text('Catat Temuan'),
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
                Text(
                  vm.errorMessage!,
                  style: const TextStyle(color: TernavaTheme.error, fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                key: const Key('incident-observation'),
                controller: _observationController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Apa yang Anda amati?',
                  hintText: 'Tulis apa adanya, tanpa menyebut penyakit.',
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'routine', label: Text('Rutin')),
                  ButtonSegment(value: 'priority', label: Text('Prioritas')),
                ],
                selected: {_attention},
                onSelectionChanged: (sel) =>
                    setState(() => _attention = sel.first),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const Key('incident-attach-photo'),
                onPressed: () {},
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(
                  vm.hasPhoto ? 'Foto dilampirkan' : 'Lampirkan foto (opsional)',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: vm.isSaving ? null : _submit,
                child: vm.isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan temuan'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    await widget.viewModel
        .saveDraft(observation: _observationController.text.trim());
    await widget.viewModel.submit(cageId: '', attention: _attention);
  }
}
