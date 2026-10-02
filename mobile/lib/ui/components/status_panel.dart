import 'package:flutter/material.dart';

import '../theme/ternava_theme.dart';

enum StatusKind { online, offline, stale, conflict, error }

class StatusPanel extends StatelessWidget {
  final StatusKind kind;
  final String label;
  final String? asOf;
  final VoidCallback? onRetry;

  const StatusPanel({
    super.key,
    required this.kind,
    required this.label,
    this.asOf,
    this.onRetry,
  });

  IconData get _icon {
    switch (kind) {
      case StatusKind.online:
        return Icons.cloud_done;
      case StatusKind.offline:
        return Icons.cloud_off;
      case StatusKind.stale:
        return Icons.history;
      case StatusKind.conflict:
        return Icons.warning_amber_rounded;
      case StatusKind.error:
        return Icons.error_outline;
    }
  }

  Color get _color {
    switch (kind) {
      case StatusKind.online:
        return TernavaTheme.success;
      case StatusKind.offline:
      case StatusKind.stale:
        return TernavaTheme.textMuted;
      case StatusKind.conflict:
        return TernavaTheme.warning;
      case StatusKind.error:
        return TernavaTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: TernavaTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TernavaTheme.border),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _color,
                  ),
                ),
                if (asOf != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    asOf!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TernavaTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}
