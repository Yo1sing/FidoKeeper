import 'package:flutter/material.dart';

class SlidingPageSwitcher extends StatefulWidget {
  const SlidingPageSwitcher({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

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
  double _dy = 0;

  @override
  void didUpdateWidget(SlidingPageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    _dy = widget.index > oldWidget.index ? 0.12 : -0.12;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 只绘制当前页，避免旧页淡出叠层和 Opacity 离屏缓冲。
    return ClipRect(
      child: SizedBox.expand(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, _dy),
            end: Offset.zero,
          ).animate(_curve),
          child: SizedBox.expand(child: RepaintBoundary(child: widget.child)),
        ),
      ),
    );
  }
}
