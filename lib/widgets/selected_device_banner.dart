import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../src/rust/api/models.dart';

class SelectedDeviceBanner extends StatelessWidget {
  const SelectedDeviceBanner({super.key, required this.device});

  final DeviceSummary? device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    if (device == null) {
      return Text(
        l10n.selectDeviceFirst,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: scheme.primary.withValues(alpha: 0.14),
          child: Icon(Icons.key, color: scheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device!.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                l10n.unlocked,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
