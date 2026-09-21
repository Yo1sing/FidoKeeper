import 'package:flutter/material.dart';

/// 只绘制当前页：切换时立刻丢掉旧 child，避免淡出叠层和 Opacity 离屏缓冲。
class SlidingPageSwitcher extends StatefulWidget {
  const SlidingPageSwitcher({
    super.key,
    required this.index,
    required this.child,
    this.axis = Axis.vertical,
    this.slideExtent = 0.12,
  });

  final int index;
  final Widget child;
  final Axis axis;

  /// 新页滑入距离，相对自身尺寸的比例。
  final double slideExtent;

  @override
  State<SlidingPageSwitcher> createState() => _SlidingPageSwitcherState();
}

class _SlidingPageSwitcherState extends State<SlidingPageSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  double _delta = 0;

  @override
  void didUpdateWidget(SlidingPageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    // 减弱动画时保持静止，避免 ticker 空转。
    if (MediaQuery.disableAnimationsOf(context)) {
      _delta = 0;
      return;
    }
    _delta = widget.index > oldWidget.index
        ? widget.slideExtent
        : -widget.slideExtent;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  Offset get _begin =>
      widget.axis == Axis.horizontal ? Offset(_delta, 0) : Offset(0, _delta);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox.expand(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: _begin,
            end: Offset.zero,
          ).animate(_curve),
          child: SizedBox.expand(child: RepaintBoundary(child: widget.child)),
        ),
      ),
    );
  }
}
