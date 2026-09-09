import 'package:flutter/material.dart';

import '../src/rust/api/keeper.dart' as backend;
import '../src/rust/api/models.dart';
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: tr('重命名指纹', 'Rename fingerprint'),
                      onPressed: busy || closing
                          ? null
                          : () => _rename(context, template),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: tr('删除指纹', 'Delete fingerprint'),
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
                  ],
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

  Future<void> _rename(
    BuildContext context,
    BioTemplateSummary template,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _RenameFingerprintDialog(initial: template.name, tr: tr),
    );
    if (name == null) return;
    await onAction(
      backend.CommandKind.renameBio,
      value: template.id,
      newPin: name,
    );
  }
}

class _RenameFingerprintDialog extends StatefulWidget {
  const _RenameFingerprintDialog({required this.initial, required this.tr});

  final String initial;
  final Translate tr;

  @override
  State<_RenameFingerprintDialog> createState() =>
      _RenameFingerprintDialogState();
}

class _RenameFingerprintDialogState extends State<_RenameFingerprintDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tr('重命名指纹', 'Rename fingerprint')),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _name,
          autofocus: true,
          maxLength: 64,
          decoration: InputDecoration(
            labelText: widget.tr('指纹名称', 'Fingerprint name'),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.tr('取消', 'Cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.tr('保存', 'Save'))),
      ],
    );
  }
}
