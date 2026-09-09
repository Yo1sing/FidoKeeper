import 'package:fidokeeper/widgets/fingerprint_enroll_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    bool failed = false,
    bool complete = false,
    bool reduceMotion = false,
    int samples = 0,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Center(
        child: FingerprintEnrollAnimation(
          failed: failed,
          complete: complete,
          samples: samples,
        ),
      ),
    ),
  );

  testWidgets('等待采样时无循环动画，采样和重试过渡结束后停止刷新', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(host(samples: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(host(failed: true, samples: 2));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(host(complete: true, samples: 6));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动画模式保留采样反馈且不持续调度帧', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);

    await tester.pumpWidget(host(reduceMotion: true, samples: 2));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
