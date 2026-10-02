import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'flock_list_view_model.dart';

class FlockListScreen extends StatefulWidget {
  final FlockListViewModel viewModel;

  const FlockListScreen({super.key, required this.viewModel});

  @override
  State<FlockListScreen> createState() => _FlockListScreenState();
}

class _FlockListScreenState extends State<FlockListScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.filter(widget.viewModel.statusFilter);
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
            title: const Text('Kelompok Ayam'),
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
            onPressed: () => Navigator.of(context).pushNamed('/flock-form'),
            icon: const Icon(Icons.add),
            label: const Text('Kelompok Baru'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'active', label: Text('Aktif')),
                    ButtonSegment(value: 'finished', label: Text('Selesai')),
                  ],
                  selected: {vm.statusFilter},
                  onSelectionChanged: (sel) => vm.filter(sel.first),
                ),
              ),
              Expanded(
                child: vm.flocks.isEmpty
                    ? Center(
                        child: Text(
                          vm.statusFilter == 'active'
                              ? 'Belum ada kelompok aktif.'
                              : 'Belum ada kelompok selesai.',
                          style: const TextStyle(color: TernavaTheme.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: vm.flocks.length,
                        itemBuilder: (context, index) {
                          final flock = vm.flocks[index];
                          return Card(
                            elevation: 0,
                            color: TernavaTheme.surface,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                color: TernavaTheme.border,
                              ),
                            ),
                            child: ListTile(
                              title: Text(
                                flock['name'] as String? ?? 'Kelompok',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: TernavaTheme.textDark,
                                ),
                              ),
                              subtitle: Text(
                                'Mulai: ${flock['start_date'] ?? '-'} · Populasi: ${flock['initial_population'] ?? '-'}',
                                style: const TextStyle(
                                  color: TernavaTheme.textMuted,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: TernavaTheme.textMuted,
                              ),
                              onTap: () => Navigator.of(context).pushNamed(
                                '/flock-form',
                                arguments: {'edit': true, 'flock': flock},
                              ),
                            ),
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
}
