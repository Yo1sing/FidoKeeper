import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import 'system_glass.dart';

const _sideItemHeight = 44.0;
const _bottomItemHeight = 64.0;
const _sideHighlightRadius = 14.0;
const _dockRadius = 28.0;
const _dockInset = 4.0;

/// 设置页内部使用的侧边栏/底栏导航。
///
/// 与主 [AppSidebar] 保持一致的玻璃材质和圆角，但菜单项由设置页自己提供。
class SettingsSidebar extends StatelessWidget {
  const SettingsSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.bottom = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// 窄屏时贴底横排。
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = [
      (Icons.palette_outlined, Icons.palette, l10n.appearance),
      (Icons.translate_outlined, Icons.translate, l10n.language),
      (
        Icons.visibility_off_outlined,
        Icons.visibility_off,
        l10n.hiddenAuthenticators,
      ),
      (Icons.info_outline, Icons.info, l10n.about),
    ];
    final safeBottom = bottom ? MediaQuery.paddingOf(context).bottom : 0.0;

    Widget item(int index, {required bool vertical}) => _SettingsNavItem(
      icon: destinations[index].$1,
      selectedIcon: destinations[index].$2,
      label: destinations[index].$3,
      selected: selectedIndex == index,
      vertical: vertical,
      onTap: () => onDestinationSelected(index),
    );

    final nav = bottom
        ? SizedBox(
            height: _bottomItemHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(child: item(i, vertical: true)),
                  ],
                );
              },
            ),
          )
        : SizedBox(
            width: 188,
            child: Column(
              children: [
                for (var i = 0; i < destinations.length; i++) ...[
                  if (i > 0) const SizedBox(height: _dockInset),
                  item(i, vertical: false),
                ],
              ],
            ),
          );

    return Padding(
      padding: bottom
          ? EdgeInsets.fromLTRB(16, 8, 16, 8 + safeBottom)
          : const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: SystemGlass(
        radius: bottom ? _dockRadius : 24,
        child: Padding(
          padding: bottom
              ? const EdgeInsets.all(_dockInset)
              : const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: nav,
        ),
      ),
    );
  }
}

class _SettingsNavItem extends StatelessWidget {
  const _SettingsNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.vertical,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool vertical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(
      vertical ? _dockRadius : _sideHighlightRadius,
    );
    final iconWidget = Icon(
      selected ? selectedIcon : icon,
      size: vertical ? 24 : 22,
      color: selected ? scheme.primary : scheme.onSurfaceVariant,
    );
    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          (vertical ? theme.textTheme.labelSmall : theme.textTheme.labelLarge)
              ?.copyWith(
                color: selected ? scheme.primary : scheme.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
    );

    return SizedBox(
      height: vertical ? _bottomItemHeight : _sideItemHeight,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: vertical
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      iconWidget,
                      const SizedBox(height: 2),
                      labelWidget,
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      iconWidget,
                      const SizedBox(width: 12),
                      Expanded(child: labelWidget),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
