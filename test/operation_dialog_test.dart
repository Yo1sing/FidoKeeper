import 'dart:async';

import 'package:fidokeeper/keeper_app.dart';
import 'package:fidokeeper/src/rust/api/keeper.dart';
import 'package:fidokeeper/src/rust/api/models.dart';
import 'package:fidokeeper/src/rust/frb_generated.dart';
import 'package:fidokeeper/ui/color_presets.dart';
import 'package:fidokeeper/widgets/app_sidebar.dart';
import 'package:fidokeeper/widgets/closing_dialog.dart';
import 'package:fidokeeper/widgets/fingerprint_enroll_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

class FakeApi extends Fake implements RustLibApi {
  Future<Snapshot> Function(Command)? operation;
  Future<Snapshot> Function()? initialize;
  Future<Snapshot> Function()? scan;
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
    credentialsLoaded: true,
    fingerprintsLoaded: false,
  );
  Snapshot _copy({
    DeviceSummary? active,
    bool clearActive = false,
    Preferences? preferences,
  }) => Snapshot(
    canManageCredentials: true,
    canManageFingerprints:
        !clearActive && (active ?? snapshot.active)?.fingerprint == true,
    devices: snapshot.devices,
    active: clearActive ? null : (active ?? snapshot.active),
    credentials: snapshot.credentials,
    existing: snapshot.existing,
    remaining: snapshot.remaining,
    templates: snapshot.templates,
    preferences: preferences ?? snapshot.preferences,
    query: snapshot.query,
    credentialsLoaded: snapshot.credentialsLoaded,
    fingerprintsLoaded: snapshot.fingerprintsLoaded,
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
        touchesHardware: const [
          CommandKind.initialize,
          CommandKind.scan,
          CommandKind.connect,
          CommandKind.listCredentials,
          CommandKind.listBio,
          CommandKind.enterFingerprints,
          CommandKind.changePin,
          CommandKind.reset,
          CommandKind.deleteCredential,
          CommandKind.deleteBio,
          CommandKind.renameBio,
          CommandKind.enrollBio,
        ].contains(kind),
        mutatesDevice: const [
          CommandKind.changePin,
          CommandKind.reset,
          CommandKind.deleteCredential,
          CommandKind.deleteBio,
          CommandKind.renameBio,
          CommandKind.enrollBio,
        ].contains(kind),
      );

  @override
  int crateApiKeeperCloseTimeoutMs({CommandKind? kind}) =>
      kind != null &&
          const [
            CommandKind.changePin,
            CommandKind.reset,
            CommandKind.deleteCredential,
            CommandKind.deleteBio,
            CommandKind.renameBio,
            CommandKind.enrollBio,
          ].contains(kind)
      ? 30000
      : 3000;

  @override
  List<String> crateApiKeeperColorSeeds() => const [
    '356859',
    '1a73e8',
    '6750a4',
    '0f766e',
    'c2410c',
    'be123c',
  ];

  @override
  String crateApiKeeperDefaultColorSeed() => '356859';

  @override
  List<String> crateApiKeeperSupportedLocales() => const [
    'system',
    'zh-CN',
    'zh-TW',
    'en-US',
  ];

  @override
  int crateApiKeeperFingerprintNameMaxBytes() => 64;

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
      return scan == null ? snapshot : scan!();
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
              BioTemplateSummary(id: template.id, name: command.name.trim())
            else
              template,
        ],
        preferences: snapshot.preferences,
        query: snapshot.query,
        credentialsLoaded: snapshot.credentialsLoaded,
        fingerprintsLoaded: snapshot.fingerprintsLoaded,
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

  testWidgets('关闭时等待进行中的扫描，超过上限也要退出并说明在等什么', (tester) async {
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
    final scan = Completer<Snapshot>();
    api.scan = () => scan.future;
    // 后端串行化：关闭请求要等正在进行的操作让出状态锁
    api.operation = (command) => command.kind == CommandKind.shutdown
        ? scan.future
        : Future.value(api.snapshot);
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('认证器'));
    await tester.pump();
    expect(api.dispatched.last, CommandKind.scan);

    final listener = tester.state(find.byType(KeeperApp)) as WindowListener;
    listener.onWindowClose();
    await tester.pump();
    expect(destroyed, isFalse);
    expect(find.byType(ClosingDialog), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ClosingDialog), findsOneWidget);
    // 限定在关闭提示内查找，避免命中操作对话框的同名标题
    expect(
      find.descendant(
        of: find.byType(ClosingDialog),
        matching: find.textContaining('扫描认证器'),
      ),
      findsOneWidget,
    );

    // 读取类操作最多等 3 秒，超时后仍然退出
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(destroyed, isTrue);

    scan.complete(api.snapshot);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('关闭时写操作等待更久，避免打断设备写入', (tester) async {
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
    final reset = Completer<Snapshot>();
    api.operation = (command) => switch (command.kind) {
      CommandKind.reset || CommandKind.shutdown => reset.future,
      _ => Future.value(api.snapshot),
    };
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置设备…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pump();
    expect(api.dispatched.last, CommandKind.reset);

    final listener = tester.state(find.byType(KeeperApp)) as WindowListener;
    listener.onWindowClose();
    await tester.pump(const Duration(milliseconds: 300));
    // 限定在关闭提示内查找，避免命中操作对话框的同名标题
    expect(
      find.descendant(
        of: find.byType(ClosingDialog),
        matching: find.textContaining('重置认证器'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(destroyed, isFalse);
    // 写操作要等满设备 I/O 上限，而不是旧的 15 秒。
    await tester.pump(const Duration(seconds: 27));
    await tester.pump();
    expect(destroyed, isTrue);

    reset.complete(api.snapshot);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('空闲时关闭不显示等待提示', (tester) async {
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
    await tester.pumpAndSettle();

    final listener = tester.state(find.byType(KeeperApp)) as WindowListener;
    listener.onWindowClose();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ClosingDialog), findsNothing);
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

  testWidgets('已加载设置时首帧即使用保存的语言', (tester) async {
    const english = Preferences(
      locale: 'en-US',
      theme: 'light',
      hiddenAuthenticators: [],
    );
    final initialization = Completer<Snapshot>();
    api.initialize = () => initialization.future;
    api.snapshot = api._copy(preferences: english);
    await tester.pumpWidget(
      const KeeperApp(desktop: false, preferences: english),
    );
    await tester.pump();
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('认证器'), findsNothing);
    initialization.complete(api.snapshot);
    await tester.pumpAndSettle();
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('认证器'), findsNothing);
  });

  testWidgets('已加载设置时首帧即使用繁体中文', (tester) async {
    const traditional = Preferences(
      locale: 'zh-TW',
      theme: 'light',
      hiddenAuthenticators: [],
    );
    final initialization = Completer<Snapshot>();
    api.initialize = () => initialization.future;
    api.snapshot = api._copy(preferences: traditional);
    await tester.pumpWidget(
      const KeeperApp(desktop: false, preferences: traditional),
    );
    await tester.pump();
    expect(find.text('認證器'), findsOneWidget);
    expect(find.text('认证器'), findsNothing);
    initialization.complete(api.snapshot);
    await tester.pumpAndSettle();
    expect(find.text('認證器'), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);
    expect(find.text('设置'), findsNothing);
  });

  testWidgets('切换语言后界面改用对应文案', (tester) async {
    api.operation = (command) async {
      if (command.kind == CommandKind.locale) {
        api.snapshot = api._copy(
          preferences: Preferences(
            locale: command.value,
            theme: api.snapshot.preferences.theme,
            hiddenAuthenticators: api.snapshot.preferences.hiddenAuthenticators,
          ),
        );
      }
      return api.snapshot;
    };
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('语言'), findsOneWidget);
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    expect(find.text('语言'), findsNWidgets(2));
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(api.last!.kind, CommandKind.locale);
    expect(api.last!.value, 'en-US');
    expect(find.text('Language'), findsNWidgets(2));
    expect(find.text('设置'), findsNothing);

    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('繁體中文').last);
    await tester.pumpAndSettle();
    expect(api.last!.kind, CommandKind.locale);
    expect(api.last!.value, 'zh-TW');
    expect(find.text('語言'), findsNWidgets(2));
    expect(find.text('设置'), findsNothing);
    expect(find.text('Settings'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsNWidgets(2));
    expect(find.text('已隱藏的認證器'), findsOneWidget);
  });

  testWidgets('语言设为跟随系统时界面使用系统语言', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    const system = Preferences(
      locale: 'system',
      theme: 'light',
      hiddenAuthenticators: [],
    );
    final initialization = Completer<Snapshot>();
    api.initialize = () => initialization.future;
    api.snapshot = api._copy(preferences: system);
    await tester.pumpWidget(
      const KeeperApp(desktop: false, preferences: system),
    );
    await tester.pump();
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('认证器'), findsNothing);
    initialization.complete(api.snapshot);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('设置页关于入口显示版本和开源许可', (tester) async {
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => <String, dynamic>{
        'appName': 'FidoKeeper',
        'packageName': 'dev.yo1sing.fidokeeper',
        'version': '1.0.0',
        'buildNumber': '1',
        'buildSignature': '',
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    expect(find.text('FIDO2 安全密钥管理工具'), findsOneWidget);
    expect(find.text('v1.0.0 (1)'), findsOneWidget);
    expect(find.text('查看许可'), findsOneWidget);
  });

  testWidgets('设置页可把语言切到跟随系统并立即换用系统语言', (tester) async {
    tester.platformDispatcher.localesTestValue = const [
      Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    api.operation = (command) async {
      if (command.kind == CommandKind.locale) {
        api.snapshot = api._copy(
          preferences: Preferences(
            locale: command.value,
            theme: api.snapshot.preferences.theme,
            hiddenAuthenticators: api.snapshot.preferences.hiddenAuthenticators,
          ),
        );
      }
      return api.snapshot;
    };
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跟随系统').last);
    await tester.pumpAndSettle();
    expect(api.last!.kind, CommandKind.locale);
    expect(api.last!.value, 'system');
    expect(find.text('語言'), findsNWidgets(2));
    expect(find.text('设置'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsNWidgets(2));
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
      expect(field.autofillHints, isEmpty);
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
    expect(pin.autofillHints, isEmpty);
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
    expect(find.byType(LinearProgressIndicator), findsNothing);
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

  testWidgets('扫描认证器时用转圈替代顶部进度条', (tester) async {
    final scan = Completer<Snapshot>();
    api.scan = () => scan.future;
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('认证器'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    scan.complete(api.snapshot);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('初始化认证器时用转圈替代顶部进度条', (tester) async {
    final initialization = Completer<Snapshot>();
    api.initialize = () => initialization.future;
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    initialization.complete(api.snapshot);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('独立页面可切换并展示未连接设备的提示', (tester) async {
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    expect(find.text('重新扫描'), findsNothing);
    expect(find.byTooltip('重新扫描'), findsNothing);
    await tester.tap(find.text('认证器'));
    await tester.pumpAndSettle();
    expect(api.dispatched.last, CommandKind.scan);
    await tester.tap(find.text('凭证'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('重新扫描'), findsNothing);
    expect(find.text('请先在认证器页面选择设备'), findsOneWidget);
    await tester.tap(find.text('指纹'));
    await tester.pumpAndSettle();
    expect(find.text('请先在认证器页面选择设备'), findsOneWidget);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('已隐藏的认证器'), findsOneWidget);
    expect(find.byType(AppSidebar), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AppSidebar), findsOneWidget);

    await tester.tap(find.text('认证器'));
    await tester.pumpAndSettle();
    expect(api.dispatched.last, CommandKind.scan);
    expect(find.byTooltip('重新扫描'), findsNothing);
    expect(find.text('测试认证器'), findsOneWidget);
    expect(find.text('轻触以选择并输入 PIN'), findsOneWidget);
    expect(find.text('CTAP2'), findsOneWidget);
    expect(find.text('PIN'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.text('凭证管理'), findsOneWidget);
    expect(find.text('本机 HID'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏隐藏设备后设置页可恢复显示', (tester) async {
    tester.view.physicalSize = const Size(200, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = api.snapshot;
    api.snapshot = Snapshot(
      canManageCredentials: original.canManageCredentials,
      canManageFingerprints: original.canManageFingerprints,
      devices: const [],
      credentials: original.credentials,
      existing: original.existing,
      remaining: original.remaining,
      templates: original.templates,
      preferences: const Preferences(
        locale: 'zh-CN',
        theme: 'light',
        hiddenAuthenticators: [
          HiddenAuthenticator(path: 'test-device', label: '测试认证器'),
        ],
      ),
      query: original.query,
      credentialsLoaded: true,
      fingerprintsLoaded: false,
    );
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已隐藏的认证器'));
    await tester.pumpAndSettle();
    expect(find.text('已隐藏的认证器'), findsOneWidget);
    expect(find.text('测试认证器'), findsOneWidget);
    expect(find.text('恢复显示'), findsOneWidget);
    await tester.tap(find.text('恢复显示'));
    await tester.pumpAndSettle();
    expect(api.dispatched.last, CommandKind.unhide);
    expect(tester.takeException(), isNull);
  });

  testWidgets('开启动态取色后不显示预设色', (tester) async {
    api.snapshot = api._copy(
      preferences: const Preferences(
        locale: 'zh-CN',
        theme: 'light',
        hiddenAuthenticators: [],
        dynamicColor: true,
      ),
    );
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    expect(find.text('动态取色'), findsOneWidget);
    expect(find.byType(ColorPresetButton), findsNothing);
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
      credentialsLoaded: true,
      fingerprintsLoaded: false,
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

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSidebar), findsOneWidget);
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();
    expect(commands.last.kind, CommandKind.theme);
    expect(commands.last.value, 'dark');
    expect(find.text('动态取色'), findsOneWidget);
    expect(find.textContaining('根据壁纸'), findsNothing);
    expect(find.byType(ColorPresetButton), findsNWidgets(6));
    await tester.tap(find.byType(ColorPresetButton).at(1));
    await tester.pumpAndSettle();
    expect(commands.last.kind, CommandKind.colorSeed);
    expect(commands.last.value, '1a73e8');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(commands.last.kind, CommandKind.dynamicColor);
    expect(commands.last.value, 'true');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AppSidebar), findsOneWidget);

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
      credentialsLoaded: true,
      fingerprintsLoaded: false,
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
      credentialsLoaded: true,
      fingerprintsLoaded: false,
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
      credentialsLoaded: true,
      fingerprintsLoaded: false,
    );
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AppSidebar), matching: find.text('指纹')),
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
    expect(api.last!.name, '右手食指');
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
      credentialsLoaded: true,
      fingerprintsLoaded: false,
    );
    final result = Completer<Snapshot>();
    api.operation = (command) {
      if (command.kind == CommandKind.enrollBio) return result.future;
      return Future.value(api.snapshot);
    };
    await tester.pumpWidget(const KeeperApp(desktop: false));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AppSidebar), matching: find.text('指纹')),
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
