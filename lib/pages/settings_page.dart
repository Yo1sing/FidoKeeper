import 'package:flutter/material.dart';

import '../src/rust/api/keeper.dart' as backend;
import '../ui/callbacks.dart';
import '../widgets/action_button.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.snapshot,
    required this.busy,
    required this.closing,
    required this.tr,
    required this.onAction,
  });

  final backend.Snapshot? snapshot;
  final bool busy;
  final bool closing;
  final Translate tr;
  final RunAction onAction;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        tr('设置', 'Settings'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: snapshot?.preferences.theme ?? 'system',
        decoration: InputDecoration(labelText: tr('主题', 'Theme')),
        items: [
          DropdownMenuItem(value: 'system', child: Text(tr('跟随系统', 'System'))),
          DropdownMenuItem(value: 'light', child: Text(tr('浅色', 'Light'))),
          DropdownMenuItem(value: 'dark', child: Text(tr('深色', 'Dark'))),
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
        decoration: InputDecoration(labelText: tr('语言', 'Language')),
        items: const [
          DropdownMenuItem(value: 'zh-CN', child: Text('简体中文')),
          DropdownMenuItem(value: 'en-US', child: Text('English')),
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
      Text(tr('已隐藏的认证器', 'Hidden authenticators')),
      for (final device in snapshot?.preferences.hiddenAuthenticators ?? [])
        ListTile(
          title: Text(device.label),
          trailing: actionButton(
            disabled: busy || closing,
            tr('恢复显示', 'Show again'),
            () => onAction(backend.CommandKind.unhide, value: device.path),
          ),
        ),
    ],
  );
}
