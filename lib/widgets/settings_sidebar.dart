import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import 'system_glass.dart';

const _sideItemHeight = 44.0;
const _sideHighlightRadius = 14.0;
const _dockInset = 4.0;

/// 桌面设置页侧栏。移动端改走设置列表，不再使用底栏切分区。
class SettingsSidebar extends StatelessWidget {
  const SettingsSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: SystemGlass(
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: SizedBox(
            width: 188,
            child: Column(
              children: [
                for (var i = 0; i < destinations.length; i++) ...[
                  if (i > 0) const SizedBox(height: _dockInset),
                  _SettingsNavItem(
                    icon: destinations[i].$1,
                    selectedIcon: destinations[i].$2,
                    label: destinations[i].$3,
                    selected: selectedIndex == i,
                    onTap: () => onDestinationSelected(i),
                  ),
                ],
              ],
            ),
          ),
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
    final radius = BorderRadius.circular(_sideHighlightRadius);
    return SizedBox(
      height: _sideItemHeight,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? scheme.primary : scheme.onSurface,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w500,
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
