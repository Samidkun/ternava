import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'login_view_model.dart';

class LoginScreen extends StatefulWidget {
  final LoginViewModel viewModel;

  const LoginScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
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
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  elevation: 0,
                  color: TernavaTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: TernavaTheme.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Masuk ke TERNAVA',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: TernavaTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Gunakan akun dari pengelola peternakan.',
                          style: TextStyle(
                            fontSize: 14,
                            color: TernavaTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (vm.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: TernavaTheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: TernavaTheme.error
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: TernavaTheme.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    vm.errorMessage!,
                                    style: const TextStyle(
                                      color: TernavaTheme.error,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (!vm.mustChangePassword) ...[
                          TextField(
                            key: const Key('username-input'),
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Nama Pengguna',
                              hintText: 'misal: operator1',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            key: const Key('password-input'),
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Kata Sandi',
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: vm.isLoading
                                ? null
                                : () {
                                    vm.submit(
                                      _usernameController.text.trim(),
                                      _passwordController.text,
                                    );
                                  },
                            child: vm.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Masuk'),
                          ),
                        ] else ...[
                          const Text(
                            'Ganti Kata Sandi Awal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: TernavaTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Akun baru wajib mengganti kata sandi sementara (minimal 8 karakter).',
                            style: TextStyle(
                              fontSize: 13,
                              color: TernavaTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            key: const Key('new-password-input'),
                            controller: _newPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Kata Sandi Baru',
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: vm.isLoading
                                ? null
                                : () {
                                    vm.changePassword(
                                      _passwordController.text,
                                      _newPasswordController.text,
                                    );
                                  },
                            child: const Text('Simpan & Lanjutkan'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
