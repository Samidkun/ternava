import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'account_view_model.dart';

class AccountScreen extends StatefulWidget {
  final AccountViewModel viewModel;

  const AccountScreen({super.key, required this.viewModel});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final profile = widget.viewModel.userProfile;
        final actor = profile?['actor'] as Map<String, dynamic>?;

        return Scaffold(
          backgroundColor: TernavaTheme.canvas,
          appBar: AppBar(
            title: const Text('Akun & Pengaturan'),
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
              Card(
                elevation: 0,
                color: TernavaTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: TernavaTheme.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actor?['display_name'] as String? ?? 'Pengguna',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: TernavaTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${actor?['username'] ?? '-'} · Peran: ${(actor?['role'] ?? 'operator').toString().toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: TernavaTheme.textMuted,
                        ),
                      ),
                      const Divider(height: 24, color: TernavaTheme.border),
                      Text(
                        'Peternakan: ${actor?['farm_name'] ?? '-'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Zona Waktu: ${actor?['timezone'] ?? 'Asia/Jakarta'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: TernavaTheme.error),
                label: const Text(
                  'Keluar Akun',
                  style: TextStyle(
                    color: TernavaTheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Keluar dari aplikasi?'),
                      content: const Text(
                        'Partisi lokal akan dikunci. Pastikan catatan offline Anda telah tersinkronisasi.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Keluar',
                            style: TextStyle(color: TernavaTheme.error),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    await widget.viewModel.logout(confirmed: true);
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
