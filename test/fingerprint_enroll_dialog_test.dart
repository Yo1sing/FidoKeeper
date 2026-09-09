import 'dart:async';

import 'package:fidokeeper/widgets/fingerprint_enroll_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets('录入成功等待完成动画再关闭，减少动画=$reduceMotion', (tester) async {
      final enrollment = Completer<void>();
      var closed = false;
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => FingerprintEnrollDialog(
                    tr: (zh, en) => zh,
                    onEnroll: () => enrollment.future,
                    samples: () => 2,
                  ),
                );
                closed = true;
              },
              child: const Text('打开'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      enrollment.complete();
      await tester.pump();

      if (!reduceMotion) {
        await tester.pump(const Duration(milliseconds: 300));
        expect(closed, isFalse);
        expect(find.byType(FingerprintEnrollDialog), findsOneWidget);
        expect(
          tester
              .widget<FingerprintEnrollAnimation>(
                find.byType(FingerprintEnrollAnimation),
              )
              .complete,
          isTrue,
        );
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isTrue);
      expect(find.byType(FingerprintEnrollDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('完成动画中卸载弹窗不会继续关闭路由', (tester) async {
    final enrollment = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: FingerprintEnrollDialog(
          tr: (zh, en) => zh,
          onEnroll: () => enrollment.future,
          samples: () => 0,
        ),
      ),
    );
    enrollment.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
