import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/locale_preference.dart';

class DesktopTitleBar extends StatefulWidget implements PreferredSizeWidget {
  const DesktopTitleBar({super.key, this.onBack});

  final VoidCallback? onBack;

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
            // 左边留 8px：AnimatedSize 展开时会创建裁剪层，
            // 不能贴着左上圆角，否则首帧会把圆角盖成直角，看起来闪一下。
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: widget.onBack == null
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                      ),
              ),
            ),
            Expanded(
              child: DragToMoveArea(
                child: SizedBox.expand(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
