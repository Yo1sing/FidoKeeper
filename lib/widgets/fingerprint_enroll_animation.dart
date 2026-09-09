import 'dart:math' as math;

import 'package:flutter/material.dart';

class FingerprintEnrollAnimation extends StatelessWidget {
  const FingerprintEnrollAnimation({
    super.key,
    this.samples = 0,
    this.complete = false,
    this.failed = false,
    this.size = 168,
    this.onComplete,
  });

  final int samples;
  final bool complete;
  final bool failed;
  final double size;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final color = failed ? scheme.error : scheme.primary;
    // 设备仅提供采样次数，完成前保留未点亮的纹路，避免暗示精确百分比。
    final progress = complete
        ? 1.0
        : 0.9 * (1 - math.pow(0.72, math.max(0, samples)));

    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        onEnd: () {
          if (complete) onComplete?.call();
        },
        builder: (context, revealed, _) => Center(
          child: SizedBox.square(
            dimension: size * 0.78,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Icon(
                  Icons.fingerprint_rounded,
                  size: size * 0.78,
                  color: scheme.onSurface.withValues(alpha: 0.12),
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      color,
                      color,
                      color.withValues(alpha: revealed == 1 ? 1 : 0),
                    ],
                    stops: [
                      0,
                      (revealed - 0.12).clamp(0.0, 1.0),
                      revealed.clamp(0.0, 1.0),
                    ],
                  ).createShader(bounds),
                  child: Opacity(
                    opacity: revealed == 0 ? 0 : 1,
                    child: Icon(Icons.fingerprint_rounded, size: size * 0.78),
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
