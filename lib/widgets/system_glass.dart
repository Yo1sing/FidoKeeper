import 'dart:ui';

import 'package:flutter/material.dart';

/// 用当前引擎的 bounded backdrop blur 做液态玻璃。
///
/// Impeller（iOS / Android / 3.47 起的桌面）走系统高斯模糊；
/// 高对比或减弱动画时退回实色，避免透明叠层。
class SystemGlass extends StatelessWidget {
  const SystemGlass({super.key, required this.child, this.radius = 24});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    // 高对比/减弱动画时系统会关掉透明材质，跟随同一策略。
    final solid = mq.highContrast || mq.disableAnimations;
    final radiusGeo = BorderRadius.circular(radius);
    final tint = scheme.surface.withValues(alpha: dark ? 0.36 : 0.5);

    final panel = solid
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: radiusGeo,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: child,
          )
        : ClipRRect(
            borderRadius: radiusGeo,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 28,
                sigmaY: 28,
                // decal 把模糊限制在裁剪区内，避免边缘串色（Flutter 3.41+ bounded blur）。
                tileMode: TileMode.decal,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radiusGeo,
                  border: Border.all(
                    color: scheme.onSurface.withValues(
                      alpha: dark ? 0.18 : 0.10,
                    ),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.alphaBlend(
                        Colors.white.withValues(alpha: dark ? 0.16 : 0.28),
                        tint,
                      ),
                      tint,
                    ],
                  ),
                ),
                child: child,
              ),
            ),
          );

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radiusGeo,
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: dark ? 0.38 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: panel,
      ),
    );
  }
}
