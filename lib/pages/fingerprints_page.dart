import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/locale_preference.dart';
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
    required this.onAction,
    required this.onPrompt,
  });

  final backend.Snapshot? snapshot;
  final bool busy;
  final bool closing;
  final RunAction onAction;
  final PromptOperation onPrompt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = snapshot?.active;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SelectedDeviceBanner(device: active),
        if (active != null) ...[
          const SizedBox(height: 16),
          if (snapshot?.canManageFingerprints != true)
            Text(l10n.fingerprintsUnsupported)
          else ...[
            actionButton(
              disabled: busy || closing,
              l10n.enrollFingerprint,
              () => onPrompt(
                context,
                backend.CommandKind.enrollBio,
                l10n.enrollFingerprint,
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
                      tooltip: l10n.renameFingerprint,
                      onPressed: busy || closing
                          ? null
                          : () => _rename(context, template),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: l10n.deleteFingerprint,
                      onPressed: busy || closing
                          ? null
                          : () => onPrompt(
                              context,
                              backend.CommandKind.deleteBio,
                              l10n.permanentlyDeleteFingerprint,
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
                  l10n.noFingerprintsEnrolled,
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
          _RenameFingerprintDialog(initial: template.name),
    );
    if (name == null) return;
    await onAction(
      backend.CommandKind.renameBio,
      value: template.id,
      name: name,
    );
  }
}

class _RenameFingerprintDialog extends StatefulWidget {
  const _RenameFingerprintDialog({required this.initial});

  final String initial;

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
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.renameFingerprint),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _name,
          autofocus: true,
          inputFormatters: [
            _Utf8ByteLimiter(backend.fingerprintNameMaxBytes()),
          ],
          decoration: InputDecoration(labelText: l10n.fingerprintName),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

/// 名称上限按 UTF-8 字节计，和设备侧以及 Rust 校验一致。
class _Utf8ByteLimiter extends TextInputFormatter {
  _Utf8ByteLimiter(this.maxBytes);

  final int maxBytes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (utf8.encode(newValue.text).length <= maxBytes) return newValue;
    var end = newValue.text.length;
    while (end > 0 &&
        utf8.encode(newValue.text.substring(0, end)).length > maxBytes) {
      end--;
    }
    final text = newValue.text.substring(0, end);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
