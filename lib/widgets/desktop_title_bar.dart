import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

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
                        Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
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
              message: '最小化',
              child: WindowCaptionButton.minimize(
                brightness: theme.brightness,
                onPressed: () => windowManager.minimize(),
              ),
            ),
            Tooltip(
              message: _maximized ? '还原' : '最大化',
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
              message: '关闭',
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
