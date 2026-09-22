import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'keeper_app.dart';
import 'src/rust/api/keeper.dart' as backend;
import 'src/rust/api/models.dart';

import 'package:fidokeeper/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'FidoKeeper',
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        minimumSize: Size(480, 320),
      ),
    );
  }
  await RustLib.init();
  // 先读设置再进入界面，避免第一帧按系统主题绘制后再切换。
  final preferences = await _loadPreferences();
  runApp(MyApp(preferences: preferences));
}

/// 启动时只读设置、不扫设备，保证第一帧就能用保存的主题。
Future<Preferences?> _loadPreferences() async {
  try {
    final snapshot = await backend.dispatch(
      command: const backend.Command(
        kind: backend.CommandKind.load,
        value: '',
        pin: '',
        newPin: '',
        confirmPin: '',
        confirmed: false,
        name: '',
      ),
    );
    return snapshot.preferences;
  } catch (_) {
    return null;
  }
}

bool get isDesktop =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.windows ||
      TargetPlatform.macOS => true,
      _ => false,
    };

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.preferences});
  final Preferences? preferences;
  @override
  Widget build(BuildContext context) =>
      KeeperApp(desktop: isDesktop, preferences: preferences);
}
