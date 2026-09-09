import 'package:flutter_test/flutter_test.dart';
import 'package:fidokeeper/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Desktop title bar controls the native window', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('认证器'), findsOneWidget);
    expect(find.byTooltip('重新扫描'), findsOneWidget);
    expect(find.text('重新扫描'), findsNothing);
    await tester.tap(find.text('凭证'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('重新扫描'), findsNothing);
    expect(find.text('凭证管理'), findsNothing);
    await tester.tap(find.text('指纹'));
    await tester.pumpAndSettle();
    expect(find.text('指纹管理'), findsNothing);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('已隐藏的认证器'), findsOneWidget);
    expect(find.text('FidoKeeper'), findsOneWidget);
    expect(await windowManager.getTitle(), 'FidoKeeper');

    await tester.tap(find.byTooltip('最大化'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(await windowManager.isMaximized(), isTrue);
    expect(find.byTooltip('还原'), findsOneWidget);

    await tester.tap(find.byTooltip('还原'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(await windowManager.isMaximized(), isFalse);

    await tester.tap(find.text('FidoKeeper'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('FidoKeeper'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(await windowManager.isMaximized(), isTrue);
    await windowManager.unmaximize();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.byTooltip('最小化'));
    await tester.runAsync(() async {
      try {
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(await windowManager.isMinimized(), isTrue);
      } finally {
        await windowManager.restore();
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
