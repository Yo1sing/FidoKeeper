import 'package:flutter/material.dart';

import '../src/rust/api/keeper.dart' as backend;
import '../ui/callbacks.dart';
import '../widgets/action_button.dart';
import '../widgets/selected_device_banner.dart';

class CredentialsPage extends StatelessWidget {
  const CredentialsPage({
    super.key,
    required this.snapshot,
    required this.busy,
    required this.closing,
    required this.tr,
    required this.onAction,
    required this.onPrompt,
    required this.searchController,
  });

  final backend.Snapshot? snapshot;
  final bool busy;
  final bool closing;
  final Translate tr;
  final RunAction onAction;
  final PromptOperation onPrompt;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final active = snapshot?.active;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          tr('凭证管理', 'Credentials'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        SelectedDeviceBanner(device: active, tr: tr),
        if (active != null) ...[
          const SizedBox(height: 16),
          if (active.credentialManagement != true)
            Text(
              tr(
                '当前认证器不支持凭证管理',
                'This authenticator does not support credentials',
              ),
            )
          else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                actionButton(
                  disabled: busy || closing,
                  tr('读取凭证', 'Read credentials'),
                  () => onAction(backend.CommandKind.listCredentials),
                  icon: Icons.refresh,
                ),
                actionButton(
                  disabled: busy || closing,
                  tr('更改 PIN', 'Change PIN'),
                  () => onPrompt(
                    context,
                    backend.CommandKind.changePin,
                    tr('更改 PIN', 'Change PIN'),
                    changePin: true,
                    askPin: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${tr('已用', 'Used')}: ${snapshot!.existing} · ${tr('剩余', 'Remaining')}: ${snapshot!.remaining}',
            ),
            TextField(
              controller: searchController,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: tr(
                  '搜索网站或用户，回车筛选',
                  'Search website or user, press Enter',
                ),
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (query) =>
                  onAction(backend.CommandKind.filter, value: query),
            ),
            const SizedBox(height: 16),
            for (final credential in snapshot!.credentials)
              Card(
                child: ListTile(
                  title: Text(credential.rpName),
                  subtitle: Text(
                    '${credential.rpId}\n${credential.userName} ${credential.userDisplayName}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: tr('删除凭证', 'Delete credential'),
                    onPressed: busy
                        ? null
                        : () => onPrompt(
                            context,
                            backend.CommandKind.deleteCredential,
                            tr('永久删除凭证', 'Permanently delete credential'),
                            value: credential.id,
                            askPin: false,
                            detail:
                                '${credential.rpId}\n${credential.userName}\n${tr('删除后可能无法再登录此账号，操作无法撤销。', 'You may lose access to this account. This cannot be undone.')}',
                          ),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            if (snapshot!.credentials.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('没有匹配的可发现凭证', 'No matching discoverable credentials'),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
