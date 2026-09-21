import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import 'system_glass.dart';

const _sideItemHeight = 44.0;
const _bottomItemHeight = 64.0;
const _itemGap = 4.0;
const _sideHighlightRadius = 14.0;
const _dockRadius = 28.0;
const _dockInset = 4.0;

/// 底栏本体高度（不含系统安全区），供内容区额外留白。
const bottomNavOverlayExtent =
    8 + _dockInset + _bottomItemHeight + _dockInset + 8;

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onOpenSettings,
    this.onScanDevices,
    this.scanEnabled = true,
    this.scanning = false,
    this.bottom = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenSettings;
  final VoidCallback? onScanDevices;
  final bool scanEnabled;
  final bool scanning;

  /// 移动端为 true，导航横排贴在屏幕底部。
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final mainDestinations = [
      (Icons.key_outlined, Icons.key, l10n.navAuthenticators),
      (Icons.password_outlined, Icons.password, l10n.navCredentials),
      (Icons.fingerprint_outlined, Icons.fingerprint, l10n.navFingerprints),
    ];
    final settingsDestination = (
      Icons.settings_outlined,
      Icons.settings,
      l10n.navSettings,
    );
    final safeBottom = bottom ? MediaQuery.paddingOf(context).bottom : 0.0;

    Widget scanButton() => IconButton(
      tooltip: l10n.scanAgain,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      onPressed: scanEnabled ? onScanDevices : null,
      icon: scanning
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          : Icon(Icons.refresh, color: scheme.primary),
    );

    Widget highlight({required bool vertical, required double itemExtent}) =>
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          top: vertical
              ? selectedIndex * (_sideItemHeight + _itemGap)
              : _dockInset,
          bottom: vertical ? null : _dockInset,
          height: vertical ? _sideItemHeight : null,
          left: vertical ? 0 : selectedIndex * itemExtent + _dockInset,
          right: vertical ? 0 : null,
          width: vertical ? null : itemExtent - _dockInset * 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(
                vertical ? _sideHighlightRadius : _dockRadius,
              ),
            ),
          ),
        );

    Widget mainItem(int index, {required bool vertical}) => _NavItem(
      icon: mainDestinations[index].$1,
      selectedIcon: mainDestinations[index].$2,
      label: mainDestinations[index].$3,
      selected: selectedIndex == index,
      vertical: vertical,
      onTap: () => onDestinationSelected(index),
      trailing: !bottom && !vertical && index == 0 && selectedIndex == 0
          ? scanButton()
          : null,
    );

    Widget settingsItem({required bool vertical}) => _NavItem(
      icon: settingsDestination.$1,
      selectedIcon: settingsDestination.$2,
      label: settingsDestination.$3,
      selected: false,
      vertical: vertical,
      onTap: onOpenSettings,
    );

    final nav = bottom
        ? SizedBox(
            height: _bottomItemHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemCount = mainDestinations.length + 1;
                final extent = constraints.maxWidth / itemCount;
                return Stack(
                  children: [
                    highlight(vertical: false, itemExtent: extent),
                    Row(
                      children: [
                        for (var i = 0; i < mainDestinations.length; i++)
                          Expanded(child: mainItem(i, vertical: true)),
                        Expanded(child: settingsItem(vertical: true)),
                      ],
                    ),
                  ],
                );
              },
            ),
          )
        : SizedBox(
            width: 188,
            child: Stack(
              children: [
                highlight(vertical: true, itemExtent: 0),
                Column(
                  children: [
                    for (var i = 0; i < mainDestinations.length; i++) ...[
                      if (i > 0) const SizedBox(height: _itemGap),
                      mainItem(i, vertical: false),
                    ],
                    const Spacer(),
                    settingsItem(vertical: false),
                  ],
                ),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.vertical,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool vertical;
  final VoidCallback onTap;
  final Widget? trailing;

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
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: vertical
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          iconWidget,
                          const SizedBox(height: 2),
                          labelWidget,
                        ],
                      ),
                    ),
                    if (trailing != null)
                      Positioned(top: 0, right: 0, child: trailing!),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      iconWidget,
                      const SizedBox(width: 12),
                      Expanded(child: labelWidget),
                      ?trailing,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
