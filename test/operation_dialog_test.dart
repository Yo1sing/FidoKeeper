import 'dart:async';

import 'package:fidokeeper/keeper_app.dart';
import 'package:fidokeeper/src/rust/api/keeper.dart';
import 'package:fidokeeper/src/rust/api/models.dart';
import 'package:fidokeeper/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi extends Fake implements RustLibApi {
  Future<Snapshot> Function(Command)? operation;
  final snapshot = Snapshot(
    devices: const [
      DeviceSummary(
        label: '测试认证器',
        path: 'test-device',
        protocol: 'CTAP2',
        credentialManagement: true,
        pin: true,
        fingerprint: false,
      ),
    ],
    credentials: const [],
    existing: BigInt.zero,
    remaining: BigInt.zero,
    templates: const [],
    preferences: const Preferences(
      locale: 'zh-CN',
      theme: 'light',
      hiddenAuthenticators: [],
    ),
    query: '',
  );
  @override
  Future<Snapshot> crateApiKeeperDispatch({required Command command}) async {
    if (command.kind == CommandKind.load || command.kind == CommandKind.scan) {
      return snapshot;
    }
    return operation == null ? snapshot : operation!(command);
  }
}

void main() {
  late FakeApi api;
  setUp(() {
    api = FakeApi();
    RustLib.initMock(api: api);
  });
  tearDown(RustLib.dispose);

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试认证器'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
  }

  testWidgets('取消后退场动画和再次打开不访问已释放控制器', (tester) async {
    await open(tester);
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试认证器'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('成功提交关闭弹窗时不会提前释放控制器', (tester) async {
    await open(tester);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('操作成功'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('失败保持弹窗并清空 PIN，重试成功后安全关闭', (tester) async {
    var attempts = 0;
    api.operation = (_) async {
      if (attempts++ == 0) throw StateError('PIN 码错误，请重试');
      return api.snapshot;
    };
    await open(tester);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PIN 码错误'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.enterText(find.byType(TextField), '5678');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('异步操作完成前卸载界面不会更新已销毁弹窗', (tester) async {
    final result = Completer<Snapshot>();
    api.operation = (_) => result.future;
    await open(tester);
    await tester.tap(find.text('确认'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    result.complete(api.snapshot);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
