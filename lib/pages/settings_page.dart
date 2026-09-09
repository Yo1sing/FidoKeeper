import 'package:flutter/material.dart';

import '../src/rust/api/keeper.dart' as backend;
import '../src/rust/api/models.dart';
import '../ui/callbacks.dart';

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
                child: Text(tr('恢复显示', 'Show again')),
              ),
            ],
          ),
        ),
    ],
  );
}
