import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../src/rust/api/keeper.dart' as backend;

/// 关闭窗口时的模态提示。
///
/// 关闭需要等正在进行的设备操作让出状态锁，设备无响应时可能等上几秒；
/// 这里说明在等哪个操作，避免看起来像卡死。挂在 MaterialApp.builder 上，
/// 因此盖在所有对话框之上，且不需要路由的生命周期管理。
class ClosingDialog extends StatelessWidget {
  const ClosingDialog({super.key, required this.operation});

  final backend.CommandKind operation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = _operationName(l10n, operation);
    final theme = Theme.of(context);
    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Color(0x99000000)),
        Center(
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.closing, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    name.isEmpty
                        ? l10n.closingWaitAny
                        : l10n.closingWaitOperation(name),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 操作名尽量复用既有文案，只有没有对应词条的才新增。
String _operationName(AppLocalizations l10n, backend.CommandKind kind) =>
    switch (kind) {
      backend.CommandKind.scan ||
      backend.CommandKind.initialize => l10n.operationScan,
      backend.CommandKind.connect => l10n.operationVerifyPin,
      backend.CommandKind.listCredentials => l10n.readCredentials,
      backend.CommandKind.enterFingerprints ||
      backend.CommandKind.listBio => l10n.operationReadFingerprints,
      backend.CommandKind.changePin => l10n.changePin,
      backend.CommandKind.deleteCredential => l10n.deleteCredential,
      backend.CommandKind.reset => l10n.resetAuthenticator,
      backend.CommandKind.enrollBio => l10n.enrollFingerprint,
      backend.CommandKind.renameBio => l10n.renameFingerprint,
      backend.CommandKind.deleteBio => l10n.deleteFingerprint,
      _ => '',
    };
