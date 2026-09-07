import 'dart:async';

import 'package:fidokeeper/keeper_app.dart';
import 'package:fidokeeper/src/rust/api/keeper.dart';
import 'package:fidokeeper/src/rust/api/models.dart';
import 'package:fidokeeper/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi extends Fake implements RustLibApi {
  Future<Snapshot> Function(Command)? operation;
  var snapshot = Snapshot(
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

  testWidgets('独立页面可切换并展示未连接设备的提示', (tester) async {
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    expect(find.text('重新扫描'), findsOneWidget);
    await tester.tap(find.text('凭证'));
    await tester.pumpAndSettle();
    expect(find.text('请先在认证器页面连接设备'), findsOneWidget);
    await tester.tap(find.text('指纹'));
    await tester.pumpAndSettle();
    expect(find.text('请连接支持指纹的认证器'), findsOneWidget);
    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();
    expect(find.text('已隐藏的认证器'), findsOneWidget);
    await tester.tap(find.text('认证器').first);
    await tester.pumpAndSettle();
    expect(find.text('测试认证器'), findsOneWidget);
    expect(find.text('轻触以连接'), findsOneWidget);
    expect(find.text('CTAP2'), findsOneWidget);
    expect(find.text('PIN'), findsOneWidget);
    expect(find.text('凭证管理'), findsOneWidget);
    expect(find.text('本机 HID'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('跨页面保留搜索内容并传递筛选、指纹和设置操作', (tester) async {
    final original = api.snapshot;
    api.snapshot = Snapshot(
      devices: original.devices,
      active: const DeviceSummary(
        label: '测试认证器',
        path: 'test-device',
        protocol: 'CTAP2',
        credentialManagement: true,
        pin: true,
        fingerprint: true,
      ),
      credentials: original.credentials,
      existing: original.existing,
      remaining: original.remaining,
      templates: original.templates,
      preferences: original.preferences,
      query: original.query,
    );
    final commands = <Command>[];
    api.operation = (command) async {
      commands.add(command);
      return api.snapshot;
    };
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('凭证'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'example.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(commands.last.kind, CommandKind.filter);
    expect(commands.last.value, 'example.com');

    await tester.tap(find.text('指纹'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('读取指纹'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(commands.last.kind, CommandKind.listBio);
    expect(commands.last.pin, '1234');
    expect(commands.last.confirmed, isTrue);

    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();
    expect(commands.last.kind, CommandKind.theme);
    expect(commands.last.value, 'dark');

    await tester.tap(find.text('凭证'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'example.com',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('认证器空列表展示扫描引导', (tester) async {
    api.snapshot = Snapshot(
      devices: const [],
      credentials: const [],
      existing: BigInt.zero,
      remaining: BigInt.zero,
      templates: const [],
      preferences: api.snapshot.preferences,
      query: '',
    );
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('未发现可用认证器'), findsOneWidget);
    expect(find.text('等待插入 USB 密钥或贴上 NFC 密钥'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已连接认证器显示状态、能力并打开详情', (tester) async {
    final original = api.snapshot;
    api.snapshot = Snapshot(
      devices: const [
        DeviceSummary(
          label: 'USB 密钥',
          path: 'usb:demo',
          protocol: 'CTAP2',
          credentialManagement: true,
          pin: true,
          fingerprint: true,
        ),
      ],
      active: const DeviceSummary(
        label: 'USB 密钥',
        path: 'usb:demo',
        protocol: 'CTAP2',
        credentialManagement: true,
        pin: true,
        fingerprint: true,
      ),
      credentials: original.credentials,
      existing: original.existing,
      remaining: original.remaining,
      templates: original.templates,
      preferences: original.preferences,
      query: original.query,
    );
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    expect(find.text('USB 密钥'), findsOneWidget);
    expect(find.text('已连接'), findsOneWidget);
    expect(find.text('USB'), findsOneWidget);
    expect(find.text('指纹'), findsNWidgets(2));
    expect(find.text('断开连接'), findsOneWidget);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('详情'));
    await tester.pumpAndSettle();
    expect(find.text('usb:demo'), findsOneWidget);
    expect(find.text('支持'), findsNWidgets(3));
    await tester.tap(find.text('关闭').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
