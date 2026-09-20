import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/locale_preference.dart';
import '../src/rust/api/keeper.dart' as backend;
import '../src/rust/api/models.dart';
import '../ui/callbacks.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.snapshot,
    required this.busy,
    required this.closing,
    required this.onAction,
  });

  final backend.Snapshot? snapshot;
  final bool busy;
  final bool closing;
  final RunAction onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        DropdownButtonFormField<String>(
          initialValue: snapshot?.preferences.theme ?? 'system',
          decoration: InputDecoration(labelText: l10n.theme),
          items: [
            DropdownMenuItem(value: 'system', child: Text(l10n.themeSystem)),
            DropdownMenuItem(value: 'light', child: Text(l10n.themeLight)),
            DropdownMenuItem(value: 'dark', child: Text(l10n.themeDark)),
          ],
          onChanged: busy || closing
              ? null
              : (value) {
                  if (value != null) {
                    onAction(backend.CommandKind.theme, value: value);
                  }
                },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: snapshot?.preferences.locale ?? 'zh-CN',
          decoration: InputDecoration(labelText: l10n.language),
          items: [
            DropdownMenuItem(
              value: systemLocalePreference,
              child: Text(l10n.languageSystem),
            ),
            DropdownMenuItem(value: 'zh-CN', child: Text(l10n.languageZh)),
            DropdownMenuItem(value: 'zh-TW', child: Text(l10n.languageZhTw)),
            DropdownMenuItem(value: 'en-US', child: Text(l10n.languageEn)),
          ],
          onChanged: busy || closing
              ? null
              : (value) {
                  if (value != null) {
                    onAction(backend.CommandKind.locale, value: value);
                  }
                },
        ),
        const SizedBox(height: 24),
        Text(l10n.hiddenAuthenticators),
        for (final device
            in snapshot?.preferences.hiddenAuthenticators ??
                const <HiddenAuthenticator>[])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(device.label),
                TextButton(
                  onPressed: busy || closing
                      ? null
                      : () => onAction(
                          backend.CommandKind.unhide,
                          value: device.path,
                        ),
                  child: Text(l10n.showAgain),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.about),
          onTap: () => _showAbout(context, l10n),
        ),
      ],
    );
  }

  Future<void> _showAbout(BuildContext context, AppLocalizations l10n) async {
    PackageInfo? info;
    try {
      info = await PackageInfo.fromPlatform();
    } catch (_) {
      // 测试或平台实现不可用时，只展示应用名和开源许可。
    }
    if (!context.mounted) return;

    final version = info == null || info.version.isEmpty
        ? null
        : info.buildNumber.isEmpty
        ? 'v${info.version}'
        : 'v${info.version} (${info.buildNumber})';

    showAboutDialog(
      context: context,
      applicationName: 'FidoKeeper',
      applicationVersion: version,
      applicationIcon: Image.asset(
        'assets/icon/fidokeeper-icon-v3.png',
        width: 56,
        height: 56,
      ),
      children: [Text(l10n.aboutDescription)],
    );
  }
}
