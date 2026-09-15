import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// 原生 PopupMenu 的矩形材质和默认字号与认证器卡片不搭，用自绘气泡菜单代替。
class ActionMenuItem {
  const ActionMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool destructive;
}

class ActionMenuButton extends StatefulWidget {
  const ActionMenuButton({
    super.key,
    required this.tooltip,
    required this.items,
    required this.onSelected,
    this.enabled = true,
  });

  final String tooltip;
  final List<ActionMenuItem> items;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  State<ActionMenuButton> createState() => _ActionMenuButtonState();
}

class _ActionMenuButtonState extends State<ActionMenuButton> {
  final _portal = OverlayPortalController();
  final _buttonKey = GlobalKey();
  Rect _anchor = Rect.zero;

  @override
  void didUpdateWidget(ActionMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _portal.isShowing) {
      _portal.hide();
    }
  }

  @override
  void dispose() {
    if (_portal.isShowing) _portal.hide();
    super.dispose();
  }

  void _toggle() {
    if (_portal.isShowing) {
      _close();
      return;
    }
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final buttonBox =
        _buttonKey.currentContext!.findRenderObject()! as RenderBox;
    final origin = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    _anchor = origin & buttonBox.size;
    _portal.show();
    setState(() {});
  }

  void _close() {
    if (!_portal.isShowing) return;
    _portal.hide();
    setState(() {});
  }

  void _select(String value) {
    _close();
    widget.onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => Positioned.fill(
        child: _ActionMenuOverlay(
          anchor: _anchor,
          items: widget.items,
          onDismiss: _close,
          onSelected: _select,
        ),
      ),
      child: IconButton(
        key: _buttonKey,
        tooltip: widget.tooltip,
        onPressed: widget.enabled ? _toggle : null,
        icon: Icon(
          Icons.more_vert,
          color: _portal.isShowing ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ActionMenuOverlay extends StatelessWidget {
  const _ActionMenuOverlay({
    required this.anchor,
    required this.items,
    required this.onDismiss,
    required this.onSelected,
  });

  final Rect anchor;
  final List<ActionMenuItem> items;
  final VoidCallback onDismiss;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final estimatedHeight = 12.0 + items.length * 44.0 + 10.0;
    final openAbove =
        anchor.bottom + 8 + estimatedHeight >
        mq.size.height - mq.padding.bottom;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Color(0x00000000)),
          ),
        ),
        CustomSingleChildLayout(
          delegate: _MenuPositionDelegate(
            anchor: anchor,
            padding: mq.padding,
            gap: 6,
            openAbove: openAbove,
          ),
          child: _MenuBubble(
            openAbove: openAbove,
            child: _MenuBody(items: items, onSelected: onSelected),
          ),
        ),
      ],
    );
  }
}

class _MenuPositionDelegate extends SingleChildLayoutDelegate {
  _MenuPositionDelegate({
    required this.anchor,
    required this.padding,
    required this.gap,
    required this.openAbove,
  });

  final Rect anchor;
  final EdgeInsets padding;
  final double gap;
  final bool openAbove;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxW = math.min(240.0, constraints.maxWidth - 16);
    return BoxConstraints(
      minWidth: 188,
      maxWidth: maxW,
      maxHeight: constraints.maxHeight - padding.vertical - 16,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = anchor.right - childSize.width + 8;
    var y = openAbove
        ? anchor.top - childSize.height - gap
        : anchor.bottom + gap;
    final minX = padding.left + 8;
    final maxX = size.width - padding.right - childSize.width - 8;
    final minY = padding.top + 8;
    final maxY = size.height - padding.bottom - childSize.height - 8;
    x = maxX < minX ? minX : x.clamp(minX, maxX);
    y = maxY < minY ? minY : y.clamp(minY, maxY);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuPositionDelegate oldDelegate) =>
      anchor != oldDelegate.anchor ||
      padding != oldDelegate.padding ||
      openAbove != oldDelegate.openAbove;
}

class _MenuBubble extends StatelessWidget {
  const _MenuBubble({required this.openAbove, required this.child});

  final bool openAbove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final solid = mq.highContrast || mq.disableAnimations;
    final reduce = mq.disableAnimations;
    const radius = 16.0;
    final tint = scheme.surface.withValues(alpha: dark ? 0.42 : 0.62);
    final fill = DecoratedBox(
      decoration: BoxDecoration(
        gradient: solid
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    Colors.white.withValues(alpha: dark ? 0.16 : 0.32),
                    tint,
                  ),
                  tint,
                ],
              ),
        color: solid ? scheme.surfaceContainer : null,
      ),
      child: Padding(padding: const EdgeInsets.all(6), child: child),
    );

    // Opacity 包 BackdropFilter 时，透明度小于 1 引擎不合成模糊，打开过程会变成实色。
    // 缩放可以包在滤镜外：首帧就启用模糊，缩放全程保持玻璃。
    final panel = Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 188, maxWidth: 240),
        child: CustomPaint(
          painter: _PanelPainter(
            radius: radius,
            border: scheme.onSurface.withValues(alpha: dark ? 0.18 : 0.10),
            shadow: scheme.shadow.withValues(alpha: dark ? 0.38 : 0.14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: solid
                ? fill
                : BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 28,
                      sigmaY: 28,
                      tileMode: TileMode.decal,
                    ),
                    child: fill,
                  ),
          ),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Transform.scale(
          scale: 0.92 + 0.08 * t,
          alignment: openAbove ? Alignment.bottomRight : Alignment.topRight,
          child: child,
        );
      },
      child: RepaintBoundary(child: panel),
    );
  }
}

class _MenuBody extends StatelessWidget {
  const _MenuBody({required this.items, required this.onSelected});

  final List<ActionMenuItem> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0 && items[i].destructive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SizedBox(
                height: 1,
                width: double.infinity,
                child: CustomPaint(
                  painter: _HairlinePainter(
                    color: scheme.outlineVariant.withValues(alpha: 0.8),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          _MenuRow(item: items[i], onSelected: onSelected),
        ],
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.onSelected});

  final ActionMenuItem item;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = item.destructive ? scheme.error : scheme.onSurface;
    final iconColor = item.destructive ? scheme.error : scheme.primary;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelected(item.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Path actionMenuPanelPath({required Size size, required double radius}) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
  );

class _PanelPainter extends CustomPainter {
  _PanelPainter({
    required this.radius,
    required this.border,
    required this.shadow,
  });

  final double radius;
  final Color border;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = actionMenuPanelPath(size: size, radius: radius);
    canvas.drawShadow(path, shadow, 16, true);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(_PanelPainter oldDelegate) =>
      radius != oldDelegate.radius ||
      border != oldDelegate.border ||
      shadow != oldDelegate.shadow;
}

class _HairlinePainter extends CustomPainter {
  _HairlinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_HairlinePainter oldDelegate) =>
      color != oldDelegate.color;
}
