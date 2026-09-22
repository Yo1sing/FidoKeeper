import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/locale_preference.dart';
import '../src/rust/api/keeper.dart' as backend;
import '../src/rust/api/models.dart';
import '../ui/callbacks.dart';
import '../ui/color_presets.dart';
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
    this.compact = false,
    this.onSubpageChanged,
  });

  final backend.Snapshot? snapshot;
  final bool busy;
  final bool closing;
  final RunAction onAction;

  /// 移动端为 true：先显示入口列表，点进去再设置。桌面仍用侧栏。
  final bool compact;
  final VoidCallback? onSubpageChanged;

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  _SettingsSection? _section;
  Future<PackageInfo?>? _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    if (!widget.compact) {
      _section = _SettingsSection.appearance;
    }
  }

  String titleFor(AppLocalizations l10n) {
    final section = _section;
    if (section == null) return l10n.navSettings;
    return _label(l10n, section);
  }

  /// 移动端子页返回列表。已在列表时返回 false，由外层关闭设置。
  bool handleBack() {
    if (!widget.compact || _section == null) return false;
    setState(() => _section = null);
    widget.onSubpageChanged?.call();
    return true;
  }

  bool get inSubpage => widget.compact && _section != null;

  Future<PackageInfo?> _loadPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      // 测试或平台实现不可用时，只展示名称和开源许可。
      return null;
    }
  }

  void _selectSection(int index) {
    _openSection(_SettingsSection.values[index]);
  }

  void _openSection(_SettingsSection section) {
    if (section == _section) return;
    setState(() {
      _section = section;
      if (section == _SettingsSection.about) {
        _packageInfoFuture ??= _loadPackageInfo();
      }
    });
    widget.onSubpageChanged?.call();
  }

  String _label(AppLocalizations l10n, _SettingsSection section) =>
      switch (section) {
        _SettingsSection.appearance => l10n.appearance,
        _SettingsSection.language => l10n.language,
        _SettingsSection.hidden => l10n.hiddenAuthenticators,
        _SettingsSection.about => l10n.about,
      };

  IconData _icon(_SettingsSection section) => switch (section) {
    _SettingsSection.appearance => Icons.palette_outlined,
    _SettingsSection.language => Icons.translate_outlined,
    _SettingsSection.hidden => Icons.visibility_off_outlined,
    _SettingsSection.about => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showingList = widget.compact && _section == null;
    final content = SlidingPageSwitcher(
      index: widget.compact ? (_section?.index ?? -1) + 1 : _section!.index,
      child: KeyedSubtree(
        key: ValueKey(_section),
        child: showingList
            ? _indexList(context, l10n)
            : _buildSection(context, l10n, _section!),
      ),
    );

    if (widget.compact) return content;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSidebar(
          selectedIndex: _section!.index,
          onDestinationSelected: _selectSection,
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _indexList(BuildContext context, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final section in _SettingsSection.values)
          ListTile(
            leading: Icon(_icon(section)),
            title: Text(_label(l10n, section)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSection(section),
          ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    AppLocalizations l10n,
    _SettingsSection section,
  ) {
    return switch (section) {
      _SettingsSection.appearance => _appearanceSection(context, l10n),
      _SettingsSection.language => _languageSection(context, l10n),
      _SettingsSection.hidden => _hiddenSection(context, l10n),
      _SettingsSection.about => _aboutSection(context, l10n),
    };
  }

  Widget _appearanceSection(BuildContext context, AppLocalizations l10n) {
    final preferences = widget.snapshot?.preferences;
    final dynamicColor = preferences?.dynamicColor ?? false;
    final selectedSeed = (preferences?.colorSeed ?? defaultColorSeed)
        .toLowerCase();
    final canEdit = !widget.busy && !widget.closing;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        DropdownButtonFormField<String>(
          initialValue: preferences?.theme ?? 'system',
          decoration: InputDecoration(labelText: l10n.theme),
          items: [
            DropdownMenuItem(value: 'system', child: Text(l10n.themeSystem)),
            DropdownMenuItem(value: 'light', child: Text(l10n.themeLight)),
            DropdownMenuItem(value: 'dark', child: Text(l10n.themeDark)),
          ],
          onChanged: canEdit
              ? (value) {
                  if (value != null) {
                    widget.onAction(backend.CommandKind.theme, value: value);
                  }
                }
              : null,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.dynamicColor),
          value: dynamicColor,
          onChanged: canEdit
              ? (value) => widget.onAction(
                  backend.CommandKind.dynamicColor,
                  value: value ? 'true' : 'false',
                )
              : null,
        ),
        if (!dynamicColor) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in colorPresets)
                ColorPresetButton(
                  key: ValueKey(colorSeedHex(color)),
                  color: color,
                  selected: colorSeedHex(color) == selectedSeed,
                  onPressed: canEdit
                      ? () => widget.onAction(
                          backend.CommandKind.colorSeed,
                          value: colorSeedHex(color),
                        )
                      : null,
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _localeLabel(AppLocalizations l10n, String code) => switch (code) {
    systemLocalePreference => l10n.languageSystem,
    'zh-CN' => l10n.languageZh,
    'zh-TW' => l10n.languageZhTw,
    'en-US' => l10n.languageEn,
    _ => code,
  };

  Widget _languageSection(BuildContext context, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        DropdownButtonFormField<String>(
          initialValue: widget.snapshot?.preferences.locale ?? 'zh-CN',
          decoration: InputDecoration(labelText: l10n.language),
          items: [
            for (final code in backend.supportedLocales())
              DropdownMenuItem(
                value: code,
                child: Text(_localeLabel(l10n, code)),
              ),
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
