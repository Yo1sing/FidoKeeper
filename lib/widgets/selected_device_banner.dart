import 'package:flutter/material.dart';

import '../src/rust/api/models.dart';
import '../ui/callbacks.dart';

class SelectedDeviceBanner extends StatelessWidget {
  const SelectedDeviceBanner({
    super.key,
    required this.device,
    required this.tr,
  });

  final DeviceSummary? device;
  final Translate tr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (device == null) {
      return Text(
        tr('请先在认证器页面选择设备', 'Select a device from Authenticators first'),
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
                tr('已解锁', 'Unlocked'),
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
