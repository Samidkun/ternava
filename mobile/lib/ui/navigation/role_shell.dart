import 'package:flutter/material.dart';

class RoleShell extends StatelessWidget {
  final String role; // 'owner', 'admin', 'operator'
  final Widget child;

  const RoleShell({super.key, required this.role, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
