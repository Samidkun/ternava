import 'package:flutter/material.dart';

import '../../core/api/generated/incident_action_input.dart';
import '../../core/api/generated/incident_assignment_input.dart';
import '../../ui/theme/ternava_theme.dart';
import 'incident_detail_view_model.dart';

class IncidentDetailScreen extends StatefulWidget {
  final IncidentDetailViewModel viewModel;

  const IncidentDetailScreen({super.key, required this.viewModel});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final pending = widget.viewModel.pendingNotes;
    if (pending != null) _notesController.text = pending;
  }

  @override
  void dispose() {
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
            title: const Text('Detail Temuan'),
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
              if (vm.isInaccessible) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TernavaTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Temuan tidak dapat diakses. Kembali ke daftar temuan.',
                    style: TextStyle(color: TernavaTheme.warning, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (vm.hasConflict) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TernavaTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Temuan sudah berubah. Muat ulang lalu coba lagi.',
                    style: TextStyle(color: TernavaTheme.error, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (vm.errorMessage != null) ...[
                Text(
                  vm.errorMessage!,
                  style: const TextStyle(
                    color: TernavaTheme.error,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                vm.observation,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: TernavaTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${vm.status} · versi ${vm.version}',
                style: const TextStyle(
                  fontSize: 13,
                  color: TernavaTheme.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('incident-notes'),
                controller: _notesController,
                enabled: !vm.isReadOnly,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan tindakan',
                ),
              ),
              const SizedBox(height: 20),
              if (!vm.isReadOnly) ...[
                if (vm.canAct)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: vm.isSubmitting
                              ? null
                              : () => _act(vm, 'in_progress'),
                          child: const Text('Tandai diproses'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: vm.isSubmitting
                              ? null
                              : () => _act(vm, 'closed'),
                          child: const Text('Tutup temuan'),
                        ),
                      ),
                    ],
                  ),
                if (vm.canAssign) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('incident-assign'),
                    onPressed: vm.isSubmitting ? null : () => _assign(vm),
                    child: const Text('Tugaskan petugas'),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _act(IncidentDetailViewModel vm, String status) async {
    final notes = _notesController.text.trim();

    if (status == 'closed' && notes.isEmpty) {
      // Surface the guard immediately, matching the server rule.
      await vm.act(
        IncidentActionInput.fromJson({
          'id': 'act-${DateTime.now().microsecondsSinceEpoch}',
          'base_version': vm.version,
          'notes': '',
          'status': status,
        }),
      );
      return;
    }

    await vm.act(
      IncidentActionInput.fromJson({
        'id': 'act-${DateTime.now().microsecondsSinceEpoch}',
        'base_version': vm.version,
        'notes': notes,
        'status': status,
      }),
    );
  }

  Future<void> _assign(IncidentDetailViewModel vm) async {
    await vm.assign(
      IncidentAssignmentInput.fromJson({
        'base_version': vm.version,
        'assignee_id': '',
      }),
    );
  }
}
