import 'dart:async';

import 'package:fidokeeper/keeper_app.dart';
import 'package:fidokeeper/src/rust/api/keeper.dart';
import 'package:fidokeeper/src/rust/api/models.dart';
import 'package:fidokeeper/src/rust/frb_generated.dart';
import 'package:fidokeeper/widgets/fingerprint_enroll_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

class FakeApi extends Fake implements RustLibApi {
  Future<Snapshot> Function(Command)? operation;
  Future<Snapshot> Function()? initialize;
  final dispatched = <CommandKind>[];
  Command? last;
  var captured = 0;
  var snapshot = Snapshot(
    canManageCredentials: true,
    canManageFingerprints: false,
    devices: const [
      DeviceSummary(
        transport: Transport.hid,
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
  Snapshot _copy({DeviceSummary? active, bool clearActive = false}) => Snapshot(
    canManageCredentials: true,
    canManageFingerprints:
        !clearActive && (active ?? snapshot.active)?.fingerprint == true,
    devices: snapshot.devices,
    active: clearActive ? null : (active ?? snapshot.active),
    credentials: snapshot.credentials,
    existing: snapshot.existing,
    remaining: snapshot.remaining,
    templates: snapshot.templates,
    preferences: snapshot.preferences,
    query: snapshot.query,
  );

  @override
  OperationInputs crateApiKeeperOperationInputs({required CommandKind kind}) =>
      OperationInputs(
        askPin: kind == CommandKind.connect,
        changePin: kind == CommandKind.changePin,
        requiresConfirmation: const [
          CommandKind.reset,
          CommandKind.deleteCredential,
          CommandKind.deleteBio,
        ].contains(kind),
      );

  @override
  int crateApiKeeperEnrollCaptured() => captured;

  @override
  Future<Snapshot> crateApiKeeperDispatch({required Command command}) async {
    dispatched.add(command.kind);
    last = command;
    if (command.kind == CommandKind.initialize) {
      return initialize == null ? snapshot : initialize!();
    }
    if (command.kind == CommandKind.scan) {
      return snapshot;
    }
    if (command.kind == CommandKind.connect) {
      if (operation != null) {
        snapshot = await operation!(command);
      }
      final matches = snapshot.devices.where(
        (item) => item.path == command.value,
      );
      if (matches.isEmpty) {
        throw StateError('认证器已断开，请重新扫描');
      }
      snapshot = _copy(active: matches.first);
      return snapshot;
    }
    if (command.kind == CommandKind.disconnect) {
      snapshot = _copy(clearActive: true);
      return snapshot;
    }
    if (command.kind == CommandKind.renameBio) {
      snapshot = Snapshot(
        canManageCredentials: snapshot.canManageCredentials,
        canManageFingerprints: snapshot.canManageFingerprints,
        devices: snapshot.devices,
        active: snapshot.active,
        credentials: snapshot.credentials,
        existing: snapshot.existing,
        remaining: snapshot.remaining,
        templates: [
          for (final template in snapshot.templates)
            if (template.id == command.value)
              BioTemplateSummary(id: template.id, name: command.newPin.trim())
            else
              template,
        ],
        preferences: snapshot.preferences,
        query: snapshot.query,
      );
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

  testWidgets('退出请求不等待业务队列，设备清理完成后才销毁窗口', (tester) async {
    final initialization = Completer<Snapshot>();
    final shutdown = Completer<Snapshot>();
    api.initialize = () => initialization.future;
    api.operation = (command) => command.kind == CommandKind.shutdown
        ? shutdown.future
        : Future.value(api.snapshot);
    var destroyed = false;
    const channel = MethodChannel('window_manager');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'destroy') destroyed = true;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pump();
    final listener = tester.state(find.byType(KeeperApp)) as WindowListener;
    listener.onWindowClose();
    await tester.pump();
    expect(api.dispatched, [CommandKind.initialize, CommandKind.shutdown]);
    expect(destroyed, isFalse);
    listener.onWindowClose();
    expect(
      api.dispatched.where((kind) => kind == CommandKind.shutdown).length,
      1,
    );
    initialization.complete(api.snapshot);
    await tester.pump();
    shutdown.complete(api.snapshot);
    await tester.pump();
    expect(destroyed, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  Finder pinField() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试认证器'));
    await tester.pumpAndSettle();
    await tester.enterText(pinField(), '1234');
  }

  testWidgets('初始化失败保留错误且不继续扫描', (tester) async {
    api.initialize = () async => throw StateError('配置读取失败');
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('配置读取失败'), findsOneWidget);
    expect(api.dispatched, [CommandKind.initialize]);
  });

  testWidgets('已加载设置时首帧即使用保存的主题，不跟随系统', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final initialization = Completer<Snapshot>();
    api.initialize = () => initialization.future;
    await tester.pumpWidget(
      const KeeperApp(
        desktop: false,
        preferences: Preferences(
          locale: 'zh-CN',
          theme: 'light',
          hiddenAuthenticators: [],
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
    expect(api.dispatched, [CommandKind.initialize]);
    initialization.complete(api.snapshot);
    await tester.pumpAndSettle();
  });

  testWidgets('忙碌时进入指纹页会在初始化后提交页面事件', (tester) async {
    final result = Completer<Snapshot>();
    api.initialize = () => result.future;
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pump();
    await tester.tap(find.text('指纹'));
    await tester.pump();
    expect(api.dispatched, [CommandKind.initialize]);
    result.complete(api.snapshot);
    await tester.pumpAndSettle();
    expect(api.dispatched, [
      CommandKind.initialize,
      CommandKind.enterFingerprints,
    ]);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('更改 PIN 按后端协议只收集新 PIN 和确认值', (tester) async {
    await open(tester);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('凭证'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更改 PIN'));
    await tester.pumpAndSettle();
    expect(pinField(), findsNWidgets(2));
    expect(find.text('设备 PIN'), findsNothing);
    for (final field in tester.widgetList<TextField>(pinField())) {
      expect(field.obscureText, isTrue);
      expect(field.keyboardType, TextInputType.visiblePassword);
    }
    await tester.enterText(pinField().at(0), '5678');
    await tester.enterText(pinField().at(1), '5678');
    Command? submitted;
    api.operation = (command) async {
      submitted = command;
      return api.snapshot;
    };
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(submitted!.kind, CommandKind.changePin);
    expect(submitted!.pin, isEmpty);
    expect(submitted!.newPin, '5678');
    expect(submitted!.confirmPin, '5678');
  });

  testWidgets('重置不收集 PIN 且确认后携带不可撤销操作确认', (tester) async {
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置设备…'));
    await tester.pumpAndSettle();
    expect(pinField(), findsNothing);
    expect(find.textContaining('此操作会永久清除'), findsOneWidget);
    Command? submitted;
    api.operation = (command) async {
      submitted = command;
      return api.snapshot;
    };
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(submitted!.kind, CommandKind.reset);
    expect(submitted!.confirmed, isTrue);
    expect(submitted!.pin, isEmpty);
  });

  testWidgets('取消后退场动画和再次打开不访问已释放控制器', (tester) async {
    await open(tester);
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试认证器'));
    await tester.pumpAndSettle();
    final pin = tester.widget<TextField>(pinField());
    expect(pin.controller!.text, isEmpty);
    expect(pin.obscureText, isTrue);
    expect(pin.keyboardType, TextInputType.visiblePassword);
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

  testWidgets('验证中隐藏 PIN 并显示转圈', (tester) async {
    final result = Completer<Snapshot>();
    api.operation = (_) => result.future;
    await open(tester);
    await tester.tap(find.text('确认'));
    await tester.pump();
    expect(pinField(), findsNothing);
    expect(find.text('设备 PIN'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('测试认证器'),
      ),
      findsNothing,
    );
    expect(find.text('取消'), findsNothing);
    expect(find.text('确认'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );
    expect(find.textContaining('正在与认证器通信'), findsOneWidget);
    result.complete(api.snapshot);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
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
    expect(tester.widget<TextField>(pinField()).controller!.text, isEmpty);
    await tester.enterText(pinField(), '5678');
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
    expect(find.text('请先在认证器页面选择设备'), findsOneWidget);
    await tester.tap(find.text('指纹'));
    await tester.pumpAndSettle();
    expect(find.text('请先在认证器页面选择设备'), findsOneWidget);
    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();
    expect(find.text('已隐藏的认证器'), findsOneWidget);
    await tester.tap(find.text('认证器').first);
    await tester.pumpAndSettle();
    expect(find.text('测试认证器'), findsOneWidget);
    expect(find.text('轻触以选择并输入 PIN'), findsOneWidget);
    expect(find.text('CTAP2'), findsOneWidget);
    expect(find.text('PIN'), findsOneWidget);
    expect(find.text('凭证管理'), findsOneWidget);
    expect(find.text('本机 HID'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('跨页面保留搜索内容并传递筛选、指纹和设置操作', (tester) async {
    final original = api.snapshot;
    api.snapshot = Snapshot(
      canManageCredentials: true,
      canManageFingerprints: true,
      devices: original.devices,
      active: const DeviceSummary(
        transport: Transport.hid,
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
    expect(find.text('测试认证器'), findsOneWidget);
    expect(find.text('已解锁'), findsOneWidget);
    expect(find.text('读取指纹'), findsNothing);
    expect(commands.last.kind, CommandKind.enterFingerprints);
    expect(commands.last.pin, isEmpty);

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
      canManageCredentials: true,
      canManageFingerprints: false,
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
      canManageCredentials: true,
      canManageFingerprints: false,
      devices: const [
        DeviceSummary(
          transport: Transport.usb,
          label: 'USB 密钥',
          path: 'opaque-device-id',
          protocol: 'CTAP2',
          credentialManagement: true,
          pin: true,
          fingerprint: true,
        ),
      ],
      active: const DeviceSummary(
        transport: Transport.usb,
        label: 'USB 密钥',
        path: 'opaque-device-id',
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
    expect(find.text('已解锁'), findsOneWidget);
    expect(find.text('USB'), findsOneWidget);
    expect(find.text('指纹'), findsNWidgets(2));
    expect(find.text('断开连接'), findsOneWidget);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('详情'));
    await tester.pumpAndSettle();
    expect(find.text('opaque-device-id'), findsOneWidget);
    expect(find.text('支持'), findsNWidgets(3));
    await tester.tap(find.text('关闭').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('选择认证器后指纹页共享同一设备', (tester) async {
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试认证器'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(pinField(), '1234');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('已解锁'), findsOneWidget);
    await tester.tap(find.text('指纹'));
    await tester.pumpAndSettle();
    expect(find.text('测试认证器'), findsOneWidget);
    expect(find.text('已解锁'), findsOneWidget);
    expect(find.text('当前认证器不支持指纹'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('指纹页可以重命名模板', (tester) async {
    const device = DeviceSummary(
      transport: Transport.usb,
      label: 'USB 密钥',
      path: 'bio-device',
      protocol: 'CTAP2',
      credentialManagement: true,
      pin: true,
      fingerprint: true,
    );
    api.snapshot = Snapshot(
      canManageCredentials: true,
      canManageFingerprints: true,
      devices: const [device],
      active: device,
      credentials: const [],
      existing: BigInt.zero,
      remaining: BigInt.zero,
      templates: const [BioTemplateSummary(id: 't1', name: 'finger')],
      preferences: api.snapshot.preferences,
      query: '',
    );
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('指纹'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('finger'), findsOneWidget);
    await tester.tap(find.byTooltip('重命名指纹'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '右手食指',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(api.last!.kind, CommandKind.renameBio);
    expect(api.last!.value, 't1');
    expect(api.last!.newPin, '右手食指');
    expect(find.text('右手食指'), findsOneWidget);
    expect(find.text('finger'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('录入指纹显示采样动画而不是进度条', (tester) async {
    const device = DeviceSummary(
      transport: Transport.usb,
      label: 'USB 密钥',
      path: 'bio-device',
      protocol: 'CTAP2',
      credentialManagement: true,
      pin: true,
      fingerprint: true,
    );
    api.snapshot = Snapshot(
      canManageCredentials: true,
      canManageFingerprints: true,
      devices: const [device],
      active: device,
      credentials: const [],
      existing: BigInt.zero,
      remaining: BigInt.zero,
      templates: const [],
      preferences: api.snapshot.preferences,
      query: '',
    );
    final result = Completer<Snapshot>();
    api.operation = (command) {
      if (command.kind == CommandKind.enrollBio) return result.future;
      return Future.value(api.snapshot);
    };
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('指纹'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('录入指纹'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FingerprintEnrollAnimation), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester
          .widget<FingerprintEnrollAnimation>(
            find.byType(FingerprintEnrollAnimation),
          )
          .samples,
      0,
    );
    expect(find.textContaining('每按一次会多显出一段纹路'), findsOneWidget);
    api.captured = 2;
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<FingerprintEnrollAnimation>(
            find.byType(FingerprintEnrollAnimation),
          )
          .samples,
      2,
    );
    result.complete(api.snapshot);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('操作成功'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
