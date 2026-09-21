import 'package:fidokeeper/widgets/sliding_page_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(int index, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: SlidingPageSwitcher(
          index: index,
          child: Text(index == 0 ? 'page-a' : 'page-b'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('切换后立刻只保留新页，动画结束停止刷新', (tester) async {
    await tester.pumpWidget(_host(0));
    expect(find.text('page-a'), findsOneWidget);
    expect(find.text('page-b'), findsNothing);

    await tester.pumpWidget(_host(1));
    await tester.pump();
    expect(find.text('page-a'), findsNothing);
    expect(find.text('page-b'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SlidingPageSwitcher),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpAndSettle();
    expect(find.text('page-b'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('减弱动画时切换不排帧', (tester) async {
    await tester.pumpWidget(_host(0, reduceMotion: true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(_host(1, reduceMotion: true));
    await tester.pump();
    expect(find.text('page-a'), findsNothing);
    expect(find.text('page-b'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
