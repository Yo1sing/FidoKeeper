import 'package:flutter/material.dart';

import '../src/rust/api/keeper.dart' as backend;
import '../ui/callbacks.dart';
import '../widgets/action_button.dart';
import '../widgets/selected_device_banner.dart';

class FingerprintsPage extends StatefulWidget {
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
  State<FingerprintsPage> createState() => _FingerprintsPageState();
}

class _FingerprintsPageState extends State<FingerprintsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _readIfReady();
    });
  }

  void _readIfReady() {
    final active = widget.snapshot?.active;
    if (widget.busy || widget.closing) return;
    if (active == null || active.fingerprint != true) return;
    widget.onAction(backend.CommandKind.listBio);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.snapshot?.active;
    final snapshot = widget.snapshot;
    final busy = widget.busy;
    final closing = widget.closing;
    final tr = widget.tr;
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
          if (active.fingerprint != true)
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
              () => widget.onPrompt(
                context,
                backend.CommandKind.enrollBio,
                tr('录入指纹', 'Enroll fingerprint'),
                askPin: false,
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
                  onPressed: busy
                      ? null
                      : () => widget.onPrompt(
                          context,
                          backend.CommandKind.deleteBio,
                          tr('永久删除指纹', 'Permanently delete fingerprint'),
                          value: template.id,
                          askPin: false,
                          detail: template.name.isEmpty
                              ? template.id
                              : template.name,
                        ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            if (snapshot.templates.isEmpty && !busy)
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
