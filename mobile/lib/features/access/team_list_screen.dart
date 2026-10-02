import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'team_list_view_model.dart';

class TeamListScreen extends StatefulWidget {
  final TeamListViewModel viewModel;

  const TeamListScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'owner':
        return 'Owner';
      default:
        return 'Operator';
    }
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
            title: const Text('Tim Peternakan'),
            backgroundColor: TernavaTheme.surface,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: TernavaTheme.border, height: 1),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: TernavaTheme.primary,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.of(context).pushNamed('/member-form'),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Tambah Anggota'),
          ),
          body: vm.members.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Belum ada anggota tim. Tambahkan operator untuk mulai mencatat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: TernavaTheme.textMuted),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.members.length,
                  itemBuilder: (context, index) {
                    final m = vm.members[index];
                    return Card(
                      elevation: 0,
                      color: TernavaTheme.surface,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: TernavaTheme.border),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              TernavaTheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            (m['display_name'] as String? ?? '?')
                                .characters
                                .first
                                .toUpperCase(),
                            style: const TextStyle(
                              color: TernavaTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          m['display_name'] as String? ?? 'Anggota',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: TernavaTheme.textDark,
                          ),
                        ),
                        subtitle: Text(
                          '@${m['username'] ?? '-'} · ${_roleLabel(m['role'] as String?)}',
                          style: const TextStyle(
                              color: TernavaTheme.textMuted),
                        ),
                        trailing: m['role'] == 'owner'
                            ? const Icon(Icons.lock_outline,
                                color: TernavaTheme.textMuted, size: 18)
                            : const Icon(Icons.edit_outlined,
                                color: TernavaTheme.textMuted),
                        onTap: () => Navigator.of(context).pushNamed(
                          '/member-form',
                          arguments: {'edit': true, 'member': m},
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
