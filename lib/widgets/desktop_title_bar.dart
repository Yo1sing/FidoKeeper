import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/locale_preference.dart';

class DesktopTitleBar extends StatefulWidget implements PreferredSizeWidget {
  const DesktopTitleBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximized();
  }

  Future<void> _syncMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) setState(() => _maximized = maximized);
  }

  @override
  void onWindowMaximize() => _syncMaximized();

  @override
  void onWindowUnmaximize() => _syncMaximized();

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: SizedBox.expand(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/icon/fidokeeper-icon-v3.png',
                          width: 18,
                          height: 18,
                          filterQuality: FilterQuality.medium,
                        ),
                        const SizedBox(width: 8),
                        Text('FidoKeeper', style: theme.textTheme.labelLarge),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Tooltip(
              message: l10n.minimizeWindow,
              child: WindowCaptionButton.minimize(
                brightness: theme.brightness,
                onPressed: () => windowManager.minimize(),
              ),
            ),
            Tooltip(
              message: _maximized ? l10n.restoreWindow : l10n.maximizeWindow,
              child: _maximized
                  ? WindowCaptionButton.unmaximize(
                      brightness: theme.brightness,
                      onPressed: () => windowManager.unmaximize(),
                    )
                  : WindowCaptionButton.maximize(
                      brightness: theme.brightness,
                      onPressed: () => windowManager.maximize(),
                    ),
            ),
            Tooltip(
              message: l10n.close,
              child: WindowCaptionButton.close(
                brightness: theme.brightness,
                onPressed: () => windowManager.close(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
