import 'package:flutter/material.dart';

import '../ui/callbacks.dart';
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
    required this.tr,
    this.onScanDevices,
    this.scanEnabled = true,
    this.scanning = false,
    this.bottom = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Translate tr;
  final VoidCallback? onScanDevices;
  final bool scanEnabled;
  final bool scanning;

  /// 移动端为 true，导航横排贴在屏幕底部。
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destinations = [
      (Icons.key_outlined, Icons.key, tr('认证器', 'Devices')),
      (Icons.password_outlined, Icons.password, tr('凭证', 'Credentials')),
      (Icons.fingerprint_outlined, Icons.fingerprint, tr('指纹', 'Fingerprints')),
      (Icons.settings_outlined, Icons.settings, tr('设置', 'Settings')),
    ];
    final safeBottom = bottom ? MediaQuery.paddingOf(context).bottom : 0.0;

    Widget scanButton() => IconButton(
      tooltip: tr('重新扫描', 'Scan again'),
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

    Widget items(double itemExtent, {required bool vertical}) {
      return Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            // 底栏高亮四边同一 inset，圆角与 dock 一致，避免上下比左右更窄。
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
          ),
          if (vertical)
            Column(
              children: [
                for (var i = 0; i < destinations.length; i++) ...[
                  if (i > 0) const SizedBox(height: _itemGap),
                  _NavItem(
                    icon: destinations[i].$1,
                    selectedIcon: destinations[i].$2,
                    label: destinations[i].$3,
                    selected: selectedIndex == i,
                    vertical: false,
                    onTap: () => onDestinationSelected(i),
                    trailing: !bottom && i == 0 && selectedIndex == 0
                        ? scanButton()
                        : null,
                  ),
                ],
              ],
            )
          else
            Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: destinations[i].$1,
                      selectedIcon: destinations[i].$2,
                      label: destinations[i].$3,
                      selected: selectedIndex == i,
                      vertical: true,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
        ],
      );
    }

    final nav = bottom
        ? SizedBox(
            height: _bottomItemHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final extent = constraints.maxWidth / destinations.length;
                return items(extent, vertical: false);
              },
            ),
          )
        : SizedBox(width: 188, child: items(0, vertical: true));

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
