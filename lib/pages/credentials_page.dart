import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
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
    required this.onAction,
    required this.onPrompt,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final backend.Snapshot? snapshot;
  final bool busy;
  final bool closing;
  final RunAction onAction;
  final PromptOperation onPrompt;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

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
          if (snapshot?.canManageCredentials != true)
            Text(l10n.credentialsUnsupported)
          else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                actionButton(
                  disabled: busy || closing,
                  l10n.readCredentials,
                  () => onAction(backend.CommandKind.listCredentials),
                  icon: Icons.refresh,
                ),
                actionButton(
                  disabled: busy || closing,
                  l10n.changePin,
                  () => onPrompt(
                    context,
                    backend.CommandKind.changePin,
                    l10n.changePin,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot?.credentialsLoaded != true)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text(
                l10n.credentialsQuota(
                  snapshot!.existing.toString(),
                  snapshot!.remaining.toString(),
                ),
              ),
              TextField(
                controller: searchController,
                enabled: !closing,
                decoration: InputDecoration(
                  labelText: l10n.searchWebsiteOrUser,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: onSearchChanged,
                onSubmitted: onSearchSubmitted,
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
                      tooltip: l10n.deleteCredential,
                      onPressed: busy || closing
                          ? null
                          : () => onPrompt(
                              context,
                              backend.CommandKind.deleteCredential,
                              l10n.permanentlyDeleteCredential,
                              value: credential.id,
                              detail: l10n.deleteCredentialDetail(
                                credential.rpId,
                                credential.userName,
                              ),
                            ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
              if (snapshot!.credentials.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.noMatchingCredentials),
                ),
            ],
          ],
        ],
      ],
    );
  }
}
