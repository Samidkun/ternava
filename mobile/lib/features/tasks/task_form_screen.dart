import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'task_form_view_model.dart';

class TaskFormScreen extends StatefulWidget {
  final TaskFormViewModel viewModel;

  const TaskFormScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _titleController = TextEditingController();
  final _sopController = TextEditingController();
  String _kind = 'routine';
  String _recurrence = 'weekly';

  @override
  void dispose() {
    _titleController.dispose();
    _sopController.dispose();
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
            title: const Text('Jadwal Tugas'),
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
                key: const Key('task-title'),
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Judul tugas'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: const Key('task-kind'),
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Jenis'),
                items: const [
                  DropdownMenuItem(value: 'routine', child: Text('Rutin')),
                  DropdownMenuItem(value: 'inspection', child: Text('Pemeriksaan')),
                  DropdownMenuItem(value: 'vaccination', child: Text('Vaksinasi')),
                ],
                onChanged: (v) => setState(() => _kind = v ?? 'routine'),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('task-sop'),
                controller: _sopController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'SOP (satu langkah per baris)',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: const Key('task-recurrence'),
                initialValue: _recurrence,
                decoration: const InputDecoration(labelText: 'Pengulangan'),
                items: const [
                  DropdownMenuItem(value: 'once', child: Text('Sekali')),
                  DropdownMenuItem(value: 'daily', child: Text('Harian')),
                  DropdownMenuItem(value: 'weekly', child: Text('Mingguan')),
                ],
                onChanged: (v) => setState(() => _recurrence = v ?? 'weekly'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: vm.isSaving ? null : _save,
                child: vm.isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan tugas'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    await widget.viewModel.save({
      'cage_id': '',
      'title': _titleController.text.trim(),
      'kind': _kind,
      'sop': _sopController.text.trim(),
      'assignee_id': '',
      'start_on': DateTime.now().toIso8601String().substring(0, 10),
      'end_on': null,
      'local_time': '06:30',
      'recurrence': _recurrence,
    });
  }
}
