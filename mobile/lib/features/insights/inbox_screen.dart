import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'inbox_view_model.dart';

/// The personal notification inbox. Items are private to their owner; opening
/// one asks the server for access first, so a revoked target never opens.
class InboxScreen extends StatefulWidget {
  final InboxViewModel viewModel;

  const InboxScreen({super.key, required this.viewModel});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        return Scaffold(
          backgroundColor: TernavaTheme.canvas,
          appBar: AppBar(
            title: const Text('Pemberitahuan'),
            backgroundColor: TernavaTheme.surface,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: TernavaTheme.border, height: 1),
            ),
          ),
          body: vm.state == InboxState.targetUnavailable
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link_off,
                          color: TernavaTheme.textMuted, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Kembali ke pemberitahuan',
                        style: TextStyle(
                          fontSize: 15,
                          color: TernavaTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tautan ini sudah tidak berlaku atau akses dicabut.',
                        style: TextStyle(
                          fontSize: 13,
                          color: TernavaTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          vm.load();
                        },
                        child: const Text('Muat ulang'),
                      ),
                    ],
                  ),
                )
              : vm.items.isEmpty
                  ? Center(
                      child: vm.isLoading
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Belum ada pemberitahuan.',
                              style: TextStyle(color: TernavaTheme.textMuted),
                            ),
                    )
                  : ListView.separated(
                      itemCount: vm.items.length,
                      separatorBuilder: (_, index) =>
                          const Divider(height: 1, color: TernavaTheme.border),
                      itemBuilder: (context, index) {
                        final item = vm.items[index];
                        return ListTile(
                          key: Key('inbox-item-${item.id}'),
                          tileColor: TernavaTheme.surface,
                          leading: Icon(
                            item.isUnread
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                            color: item.isUnread
                                ? TernavaTheme.primary
                                : TernavaTheme.textMuted,
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: item.isUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: TernavaTheme.textDark,
                            ),
                          ),
                          subtitle: Text(
                            item.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: TernavaTheme.textMuted,
                            ),
                          ),
                          onTap: () => vm.open(item.id),
                        );
                      },
                    ),
        );
      },
    );
  }
}
