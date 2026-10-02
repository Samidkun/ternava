import 'package:flutter/material.dart';

import '../../ui/components/status_panel.dart';
import '../../ui/theme/ternava_theme.dart';
import 'today_view_model.dart';

class TodayScreen extends StatefulWidget {
  final TodayViewModel viewModel;

  const TodayScreen({super.key, required this.viewModel});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
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
            title: const Text('Tugas Hari Ini'),
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
              const StatusPanel(
                kind: StatusKind.online,
                label: 'Semua antrean lokal tersinkronisasi',
                asOf: 'Hari ini',
              ),
              const SizedBox(height: 16),
              const Text(
                'Daftar Kandang Anda',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: TernavaTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              if (vm.cages.isEmpty)
                Card(
                  elevation: 0,
                  color: TernavaTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: TernavaTheme.border),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Belum ada kandang yang ditugaskan kepada Anda.',
                        style: TextStyle(color: TernavaTheme.textMuted),
                      ),
                    ),
                  ),
                )
              else
                ...vm.cages.map((cage) {
                  return Card(
                    elevation: 0,
                    color: TernavaTheme.surface,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: TernavaTheme.border),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          '/daily-form',
                          arguments: {
                            'cage_id': cage.id,
                            'cage_name': cage.name,
                          },
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cage.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: TernavaTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kode: ${cage.code}',
                              style: const TextStyle(
                                color: TernavaTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cage.hasRecordedToday
                                          ? TernavaTheme.success.withValues(
                                              alpha: 0.1,
                                            )
                                          : TernavaTheme.warning.withValues(
                                              alpha: 0.1,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      cage.hasRecordedToday
                                          ? 'Sudah dicatat'
                                          : 'Belum dicatat',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: cage.hasRecordedToday
                                            ? TernavaTheme.success
                                            : TernavaTheme.warning,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.chevron_right,
                                  color: TernavaTheme.textMuted,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
