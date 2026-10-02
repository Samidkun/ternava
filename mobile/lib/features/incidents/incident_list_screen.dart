import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'incident_list_view_model.dart';

class IncidentListScreen extends StatefulWidget {
  final IncidentListViewModel viewModel;

  const IncidentListScreen({super.key, required this.viewModel});

  @override
  State<IncidentListScreen> createState() => _IncidentListScreenState();
}

class _IncidentListScreenState extends State<IncidentListScreen> {
  String _statusFilter = 'all';
  String _assignmentFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        return Scaffold(
          backgroundColor: TernavaTheme.canvas,
          appBar: AppBar(
            title: const Text('Temuan'),
            backgroundColor: TernavaTheme.surface,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: TernavaTheme.border, height: 1),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: const Key('incident-filter-status'),
                        initialValue: _statusFilter,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Semua')),
                          DropdownMenuItem(
                            value: 'open',
                            child: Text('Terbuka'),
                          ),
                          DropdownMenuItem(
                            value: 'in_progress',
                            child: Text('Diproses'),
                          ),
                          DropdownMenuItem(
                            value: 'closed',
                            child: Text('Tutup'),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _statusFilter = v ?? 'all');
                          _applyFilter();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: const Key('incident-filter-assignment'),
                        initialValue: _assignmentFilter,
                        decoration: const InputDecoration(
                          labelText: 'Penugasan',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Semua')),
                          DropdownMenuItem(
                            value: 'unassigned',
                            child: Text('Belum ditugaskan'),
                          ),
                          DropdownMenuItem(
                            value: 'assigned',
                            child: Text('Sudah ditugaskan'),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _assignmentFilter = v ?? 'all');
                          _applyFilter();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: vm.rows.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada temuan.',
                          style: TextStyle(color: TernavaTheme.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: vm.rows.length,
                        separatorBuilder: (_, index) => const Divider(
                          height: 1,
                          color: TernavaTheme.border,
                        ),
                        itemBuilder: (context, index) {
                          final row = vm.rows[index];
                          return ListTile(
                            key: Key('incident-row-${row.id}'),
                            title: Text(row.observation),
                            subtitle: Text(
                              '${row.status} · ${row.displayObservedAt()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: TernavaTheme.textMuted,
                              ),
                            ),
                            trailing: row.assigneeId == null
                                ? const Text(
                                    'Belum ditugaskan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: TernavaTheme.warning,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _applyFilter() async {
    final query = <String, Object?>{};
    if (_statusFilter != 'all') query['status'] = _statusFilter;
    if (_assignmentFilter != 'all') query['assigned'] = _assignmentFilter;
    await widget.viewModel.filter(query);
  }
}
