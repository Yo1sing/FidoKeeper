import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'keeper_app.dart';

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
  runApp(const MyApp());
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
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => KeeperApp(desktop: isDesktop);
}
