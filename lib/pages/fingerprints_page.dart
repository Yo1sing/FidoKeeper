import 'package:flutter/material.dart';

import '../src/rust/api/keeper.dart' as backend;
import '../ui/callbacks.dart';
import '../widgets/action_button.dart';

class FingerprintsPage extends StatelessWidget {
  const FingerprintsPage({
    super.key,
    required this.snapshot,
    required this.busy,
    required this.closing,
    required this.tr,
    required this.onPrompt,
  });

  final backend.Snapshot? snapshot;
  final bool busy;
  final bool closing;
  final Translate tr;
  final PromptOperation onPrompt;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        tr('指纹管理', 'Fingerprints'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      if (snapshot?.active?.fingerprint != true)
        Text(
          tr(
            '请连接支持指纹的认证器',
            'Connect an authenticator with fingerprint support',
          ),
        )
      else ...[
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            actionButton(
              disabled: busy || closing,
              tr('读取指纹', 'Read fingerprints'),
              () => onPrompt(
                context,
                backend.CommandKind.listBio,
                tr('读取指纹', 'Read fingerprints'),
              ),
            ),
            actionButton(
              disabled: busy || closing,
              tr('录入指纹', 'Enroll fingerprint'),
              () => onPrompt(
                context,
                backend.CommandKind.enrollBio,
                tr('录入指纹', 'Enroll fingerprint'),
                detail: tr(
                  '提交后请在设备上重复采样。完成后重新读取指纹列表。',
                  'Touch the sensor repeatedly when prompted. Refresh the list after enrollment.',
                ),
              ),
            ),
          ],
        ),
        for (final template in snapshot!.templates)
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(template.name.isEmpty ? template.id : template.name),
            trailing: IconButton(
              onPressed: busy
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
      ],
    ],
  );
}
