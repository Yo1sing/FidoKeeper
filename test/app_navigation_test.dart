import 'package:fidokeeper/keeper_app.dart';
import 'package:fidokeeper/src/rust/api/keeper.dart';
import 'package:fidokeeper/src/rust/api/models.dart';
import 'package:fidokeeper/src/rust/frb_generated.dart';
import 'package:fidokeeper/ui/callbacks.dart';
import 'package:fidokeeper/widgets/app_sidebar.dart';
import 'package:fidokeeper/widgets/system_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends Fake implements RustLibApi {
  @override
  Future<Snapshot> crateApiKeeperDispatch({required Command command}) async {
    return Snapshot(
      canManageCredentials: false,
      canManageFingerprints: false,
      devices: [],
      credentials: [],
      existing: BigInt.zero,
      remaining: BigInt.zero,
      templates: [],
      preferences: Preferences(
        locale: 'zh-CN',
        theme: 'light',
        hiddenAuthenticators: [],
      ),
      query: '',
    );
  }

  @override
  OperationInputs crateApiKeeperOperationInputs({required CommandKind kind}) =>
      const OperationInputs(
        askPin: false,
        changePin: false,
        requiresConfirmation: false,
      );

  @override
  int crateApiKeeperEnrollCaptured() => 0;
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Translate get _tr =>
    (zh, en) => zh;

void main() {
  testWidgets('侧栏纵向排列，底栏横向排列', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AppSidebar(selectedIndex: 0, onDestinationSelected: (_) {}, tr: _tr),
      ),
    );
    final sideDevices = tester.getRect(find.text('认证器'));
    final sideCreds = tester.getRect(find.text('凭证'));
    expect(sideCreds.top, greaterThan(sideDevices.bottom));

    await tester.pumpWidget(
      _wrap(
        AppSidebar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          tr: _tr,
          bottom: true,
        ),
      ),
    );
    final bottomDevices = tester.getRect(find.text('认证器'));
    final bottomCreds = tester.getRect(find.text('凭证'));
    expect(bottomCreds.left, greaterThan(bottomDevices.right));
    expect(
      (bottomDevices.center.dy - bottomCreds.center.dy).abs(),
      lessThan(8),
    );
  });

  testWidgets('玻璃材质使用 bounded blur，高对比时退回实色', (tester) async {
    await tester.pumpWidget(
      _wrap(const SystemGlass(child: SizedBox(width: 80, height: 80))),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: true),
          child: child!,
        ),
        home: const Scaffold(
          body: SystemGlass(child: SizedBox(width: 80, height: 80)),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('桌面扫描中刷新按钮变为转圈', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AppSidebar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          onScanDevices: () {},
          scanning: true,
          scanEnabled: false,
          tr: _tr,
        ),
      ),
    );
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('重新扫描'), findsOneWidget);
  });

  testWidgets('移动端把导航放在屏幕下半部', (tester) async {
    RustLib.initMock(api: _FakeApi());
    addTearDown(RustLib.dispose);
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    final nav = tester.getRect(find.byType(AppSidebar));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(nav.center.dy, greaterThan(screen.height / 2));
    expect(nav.bottom, closeTo(screen.bottom, 24));
  });
}
