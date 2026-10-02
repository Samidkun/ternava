import 'package:flutter/material.dart';

import '../../core/api/generated/task_result_input.dart';
import '../../ui/theme/ternava_theme.dart';
import 'task_detail_view_model.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskDetailViewModel viewModel;

  const TaskDetailScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
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
            title: const Text('Detail Tugas'),
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
              if (vm.needsReview) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TernavaTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: TernavaTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Tugas ini perlu ditinjau ulang.',
                    style: TextStyle(color: TernavaTheme.error, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                vm.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: TernavaTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                vm.sop,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: TernavaTheme.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Daftar periksa',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: TernavaTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < vm.checklistItems.length; i++)
                CheckboxListTile(
                  key: Key('check-item-${i + 1}'),
                  value: vm.isChecked(vm.checklistItems[i]['id'] as String),
                  onChanged: vm.isReadOnly
                      ? null
                      : (value) => vm.toggle(
                            vm.checklistItems[i]['id'] as String,
                            value ?? false,
                          ),
                  title: Text(vm.checklistItems[i]['label'] as String),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('task-note'),
                controller: _noteController,
                enabled: !vm.isReadOnly,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: vm.isReadOnly || vm.isSubmitting
                          ? null
                          : () => _submit(vm, 'note'),
                      child: const Text('Simpan catatan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: vm.isReadOnly || vm.isSubmitting
                          ? null
                          : () => _submit(vm, 'completed'),
                      child: const Text('Selesai'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit(TaskDetailViewModel vm, String status) async {
    final note = _noteController.text.trim();
    final values = vm.checklistItems
        .map((item) => {
              'id': item['id'],
              'checked': vm.isChecked(item['id'] as String),
            })
        .toList();

    await vm.submit(TaskResultInput.fromJson({
      'id': 'res-${DateTime.now().microsecondsSinceEpoch}',
      'base_version': 1,
      'status': status,
      'notes': note.isEmpty ? null : note,
      'checklist_values': values,
    }));
  }
}
