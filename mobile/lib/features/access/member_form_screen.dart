import 'package:flutter/material.dart';

import '../../ui/theme/ternava_theme.dart';
import 'member_form_view_model.dart';

class MemberFormScreen extends StatefulWidget {
  final MemberFormViewModel viewModel;
  final bool edit;
  final Map<String, dynamic>? initial;

  const MemberFormScreen({
    super.key,
    required this.viewModel,
    this.edit = false,
    this.initial,
  });

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _usernameController.text = init['username'] as String? ?? '';
      _displayNameController.text = init['display_name'] as String? ?? '';
      _selectedRole = init['role'] as String?;
    }
    _selectedRole ??= widget.viewModel.assignableRoles.first;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _roleLabel(String role) {
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
        final roles = vm.assignableRoles;

        return Scaffold(
          backgroundColor: TernavaTheme.canvas,
          appBar: AppBar(
            title: Text(widget.edit ? 'Ubah Anggota' : 'Anggota Baru'),
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
              if (vm.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TernavaTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: TernavaTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    vm.errorMessage!,
                    style: const TextStyle(
                        color: TernavaTheme.error, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const Key('username'),
                controller: _usernameController,
                enabled: !widget.edit,
                decoration: const InputDecoration(
                  labelText: 'Nama Pengguna',
                  hintText: 'misal: operator_budi',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('display-name'),
                controller: _displayNameController,
                decoration: const InputDecoration(labelText: 'Nama Tampilan'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: const Key('role'),
                initialValue: _selectedRole,
                decoration: const InputDecoration(labelText: 'Peran'),
                items: roles
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(_roleLabel(r)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRole = v),
              ),
              if (!widget.edit) ...[
                const SizedBox(height: 14),
                TextField(
                  key: const Key('temporary-password'),
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata Sandi Sementara',
                    helperText:
                        'Minimal 12 karakter. Tidak disimpan di perangkat.',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: vm.isSaving
                    ? null
                    : () async {
                        final values = {
                          'username': _usernameController.text.trim(),
                          'display_name': _displayNameController.text.trim(),
                          'role': _selectedRole,
                          if (!widget.edit)
                            'temporary_password': _passwordController.text,
                        };
                        final ok = widget.edit
                            ? await vm.update(values,
                                id: widget.initial?['id'] as String? ?? '')
                            : await vm.create(values);
                        // Clear the secret from memory immediately.
                        _passwordController.clear();
                        if (ok && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                child: vm.isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan anggota'),
              ),
            ],
          ),
        );
      },
    );
  }
}
