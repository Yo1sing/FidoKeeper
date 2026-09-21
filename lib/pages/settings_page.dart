import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/locale_preference.dart';
import '../src/rust/api/keeper.dart' as backend;
import '../src/rust/api/models.dart';
import '../ui/callbacks.dart';
import '../widgets/settings_sidebar.dart';
import '../widgets/sliding_page_switcher.dart';

enum _SettingsSection { appearance, language, hidden, about }

class SettingsPage extends StatefulWidget {
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
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  _SettingsSection _section = _SettingsSection.appearance;
  Future<PackageInfo?>? _packageInfoFuture;

  Future<PackageInfo?> _loadPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      // 测试或平台实现不可用时，只展示名称和开源许可。
      return null;
    }
  }

  void _selectSection(int index) {
    final section = _SettingsSection.values[index];
    if (section == _section) return;
    setState(() {
      _section = section;
      if (section == _SettingsSection.about) {
        _packageInfoFuture ??= _loadPackageInfo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final content = SlidingPageSwitcher(
      index: _section.index,
      child: KeyedSubtree(
        key: ValueKey(_section),
        child: _buildSection(context, l10n),
      ),
    );

    if (compact) {
      return Column(
        children: [
          Expanded(child: content),
          SettingsSidebar(
            selectedIndex: _section.index,
            onDestinationSelected: _selectSection,
            bottom: true,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSidebar(
          selectedIndex: _section.index,
          onDestinationSelected: _selectSection,
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildSection(BuildContext context, AppLocalizations l10n) {
    return switch (_section) {
      _SettingsSection.appearance => _appearanceSection(context, l10n),
      _SettingsSection.language => _languageSection(context, l10n),
      _SettingsSection.hidden => _hiddenSection(context, l10n),
      _SettingsSection.about => _aboutSection(context, l10n),
    };
  }

  Widget _appearanceSection(BuildContext context, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        DropdownButtonFormField<String>(
          initialValue: widget.snapshot?.preferences.theme ?? 'system',
          decoration: InputDecoration(labelText: l10n.theme),
          items: [
            DropdownMenuItem(value: 'system', child: Text(l10n.themeSystem)),
            DropdownMenuItem(value: 'light', child: Text(l10n.themeLight)),
            DropdownMenuItem(value: 'dark', child: Text(l10n.themeDark)),
          ],
          onChanged: widget.busy || widget.closing
              ? null
              : (value) {
                  if (value != null) {
                    widget.onAction(backend.CommandKind.theme, value: value);
                  }
                },
        ),
      ],
    );
  }

  Widget _languageSection(BuildContext context, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        DropdownButtonFormField<String>(
          initialValue: widget.snapshot?.preferences.locale ?? 'zh-CN',
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
          onChanged: widget.busy || widget.closing
              ? null
              : (value) {
                  if (value != null) {
                    widget.onAction(backend.CommandKind.locale, value: value);
                  }
                },
        ),
      ],
    );
  }

  Widget _hiddenSection(BuildContext context, AppLocalizations l10n) {
    final hidden =
        widget.snapshot?.preferences.hiddenAuthenticators ??
        const <HiddenAuthenticator>[];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (hidden.isEmpty)
          Text(
            l10n.noHiddenAuthenticators,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final device in hidden)
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
                    onPressed: widget.busy || widget.closing
                        ? null
                        : () => widget.onAction(
                            backend.CommandKind.unhide,
                            value: device.path,
                          ),
                    child: Text(l10n.showAgain),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _aboutSection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        FutureBuilder<PackageInfo?>(
          future: _packageInfoFuture ??= _loadPackageInfo(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            final version = info == null || info.version.isEmpty
                ? null
                : info.buildNumber.isEmpty
                ? 'v${info.version}'
                : 'v${info.version} (${info.buildNumber})';

            Widget icon() => Image.asset(
              'assets/icon/fidokeeper-icon-v3.png',
              width: 56,
              height: 56,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    icon(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FidoKeeper', style: theme.textTheme.titleLarge),
                          if (version != null) ...[
                            const SizedBox(height: 4),
                            Text(version, style: theme.textTheme.bodyMedium),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            l10n.aboutDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'FidoKeeper',
                    applicationVersion: version,
                    applicationIcon: icon(),
                  ),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(
                    MaterialLocalizations.of(context).viewLicensesButtonLabel,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
