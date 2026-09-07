import 'package:flutter/material.dart';

import '../src/rust/api/keeper.dart' as backend;
import '../src/rust/api/models.dart';
import '../ui/callbacks.dart';
import '../widgets/action_button.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({
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
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        tr('认证器', 'Authenticators'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                tr(
                  '插入 USB 密钥或贴上 NFC 密钥后重新扫描。首次 USB 连接需要授权，NFC 操作期间请保持贴紧。所有操作均在本机完成。',
                  'Scan after inserting a USB key or holding an NFC key. USB needs a one-time permission; keep NFC in range during operations. All operations stay on this device.',
                ),
              ),
              actionButton(
                disabled: busy || closing,
                tr('重新扫描', 'Scan again'),
                () => onAction(backend.CommandKind.scan),
                icon: Icons.refresh,
              ),
            ],
          ),
        ),
      ),
      if (snapshot != null && snapshot!.devices.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr(
              '未发现可用认证器；请检查连接、设备权限或隐藏列表。',
              'No authenticators found. Check connections, device permissions, or hidden devices.',
            ),
          ),
        ),
      for (final device in snapshot?.devices ?? <DeviceSummary>[])
        Card(
          child: ListTile(
            leading: const Icon(Icons.key),
            title: Text(device.label),
            subtitle: snapshot?.active?.path == device.path
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(Icons.circle, color: Colors.green, size: 8),
                  )
                : null,
            onTap: busy || closing
                ? null
                : () => onPrompt(
                    context,
                    backend.CommandKind.connect,
                    tr('连接认证器', 'Connect authenticator'),
                    value: device.path,
                    detail: device.label,
                  ),
            trailing: PopupMenuButton<String>(
              enabled: !busy && !closing,
              onSelected: (action) {
                switch (action) {
                  case 'details':
                    showDialog<void>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(device.label),
                        content: SelectableText(
                          '${device.path}\n${device.protocol}\n${tr('凭证管理', 'Credential management')}: ${device.credentialManagement}\nPIN: ${device.pin}\n${tr('指纹', 'Fingerprint')}: ${device.fingerprint}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: Text(tr('关闭', 'Close')),
                          ),
                        ],
                      ),
                    );
                  case 'disconnect':
                    onAction(backend.CommandKind.disconnect);
                  case 'hide':
                    onAction(backend.CommandKind.hide_, value: device.path);
                  case 'reset':
                    onPrompt(
                      context,
                      backend.CommandKind.reset,
                      tr('重置认证器', 'Reset authenticator'),
                      value: device.path,
                      reset: true,
                      detail:
                          '${device.label}\n${tr('此操作会永久清除全部凭证、PIN 和指纹，无法撤销。请重新插入设备后立即确认，并按设备提示触碰。', 'This permanently erases all credentials, PIN and fingerprints. Reinsert the device, confirm immediately, then touch it as prompted.')}',
                    );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'details',
                  child: Text(tr('详情', 'Details')),
                ),
                if (snapshot?.active?.path == device.path)
                  PopupMenuItem(
                    value: 'disconnect',
                    child: Text(tr('断开连接', 'Disconnect')),
                  ),
                PopupMenuItem(
                  value: 'hide',
                  child: Text(tr('隐藏设备', 'Hide device')),
                ),
                PopupMenuItem(
                  value: 'reset',
                  child: Text(tr('重置设备…', 'Reset device…')),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
