import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'cage_list_view_model.dart';

class CageListScreen extends StatefulWidget {
  final CageListViewModel viewModel;
  final bool canManage;

  const CageListScreen({
    super.key,
    required this.viewModel,
    this.canManage = true,
  });

  @override
  State<CageListScreen> createState() => _CageListScreenState();
}

class _CageListScreenState extends State<CageListScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
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
            title: const Text('Kandang'),
            backgroundColor: TernavaTheme.surface,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: TernavaTheme.border, height: 1),
            ),
          ),
          floatingActionButton: widget.canManage
              ? FloatingActionButton.extended(
                  backgroundColor: TernavaTheme.primary,
                  foregroundColor: Colors.white,
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/cage-form'),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Kandang'),
                )
              : null,
          body: vm.cages.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada kandang.',
                    style: TextStyle(color: TernavaTheme.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.cages.length,
                  itemBuilder: (context, index) {
                    final cage = vm.cages[index];
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
                          backgroundColor: TernavaTheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            (cage['code'] as String? ?? '?').characters.first
                                .toUpperCase(),
                            style: const TextStyle(
                              color: TernavaTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          cage['name'] as String? ?? 'Kandang',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: TernavaTheme.textDark,
                          ),
                        ),
                        subtitle: Text(
                          'Kode: ${cage['code'] ?? '-'}',
                          style: const TextStyle(color: TernavaTheme.textMuted),
                        ),
                        trailing: widget.canManage
                            ? const Icon(
                                Icons.edit_outlined,
                                color: TernavaTheme.textMuted,
                              )
                            : null,
                        onTap: widget.canManage
                            ? () => Navigator.of(context).pushNamed(
                                '/cage-form',
                                arguments: {'edit': true, 'cage': cage},
                              )
                            : null,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
