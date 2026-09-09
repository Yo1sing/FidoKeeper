import 'dart:ui';

import 'package:flutter/material.dart';

import '../ui/callbacks.dart';

const _itemHeight = 44.0;
const _itemGap = 4.0;

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.tr,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Translate tr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    const radius = 24.0;
    final destinations = [
      (Icons.key_outlined, Icons.key, tr('认证器', 'Devices')),
      (Icons.password_outlined, Icons.password, tr('凭证', 'Credentials')),
      (Icons.fingerprint_outlined, Icons.fingerprint, tr('指纹', 'Fingerprints')),
      (Icons.settings_outlined, Icons.settings, tr('设置', 'Settings')),
    ];

    return Padding(
      // 与窗口边缘留白，形成悬浮卡片而不是贴边栏。
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: dark ? 0.38 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: dark ? 0.42 : 0.58),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: scheme.onSurface.withValues(
                      alpha: dark ? 0.16 : 0.10,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: 188,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          top: selectedIndex * (_itemHeight + _itemGap),
                          left: 0,
                          right: 0,
                          height: _itemHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            for (var i = 0; i < destinations.length; i++) ...[
                              if (i > 0) const SizedBox(height: _itemGap),
                              _SidebarItem(
                                icon: destinations[i].$1,
                                selectedIcon: destinations[i].$2,
                                label: destinations[i].$3,
                                selected: selectedIndex == i,
                                onTap: () => onDestinationSelected(i),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(14);
    return SizedBox(
      height: _itemHeight,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 22,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? scheme.primary : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
