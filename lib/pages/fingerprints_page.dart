import 'package:flutter/material.dart';

import '../src/rust/api/keeper.dart' as backend;
import '../ui/callbacks.dart';
import '../widgets/action_button.dart';
import '../widgets/selected_device_banner.dart';

class FingerprintsPage extends StatelessWidget {
  const FingerprintsPage({
    super.key,
    required this.snapshot,
    required this.busy,
    required this.closing,
    required this.tr,
    required this.onAction,
    required this.onPrompt,
  });

  final backend.Snapshot? snapshot;
  final bool busy;
  final bool closing;
  final Translate tr;
  final RunAction onAction;
  final PromptOperation onPrompt;

  @override
  Widget build(BuildContext context) {
    final active = snapshot?.active;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          tr('指纹管理', 'Fingerprints'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        SelectedDeviceBanner(device: active, tr: tr),
        if (active != null) ...[
          const SizedBox(height: 16),
          if (snapshot?.canManageFingerprints != true)
            Text(
              tr(
                '当前认证器不支持指纹',
                'This authenticator does not support fingerprints',
              ),
            )
          else ...[
            actionButton(
              disabled: busy || closing,
              tr('录入指纹', 'Enroll fingerprint'),
              () => onPrompt(
                context,
                backend.CommandKind.enrollBio,
                tr('录入指纹', 'Enroll fingerprint'),
                detail: tr(
                  '提交后请在设备上重复采样。',
                  'Touch the sensor repeatedly when prompted.',
                ),
              ),
            ),
            for (final template in snapshot!.templates)
              ListTile(
                leading: const Icon(Icons.fingerprint),
                title: Text(
                  template.name.isEmpty ? template.id : template.name,
                ),
                trailing: IconButton(
                  onPressed: busy || closing
                      ? null
                      : () => onPrompt(
                          context,
                          backend.CommandKind.deleteBio,
                          tr('永久删除指纹', 'Permanently delete fingerprint'),
                          value: template.id,
                          detail: template.name.isEmpty
                              ? template.id
                              : template.name,
                        ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            if (snapshot!.templates.isEmpty && !busy)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  tr('尚未录入指纹', 'No fingerprints enrolled'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
