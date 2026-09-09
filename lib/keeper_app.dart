import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/rust/api/keeper.dart' as backend;
import 'pages/devices_page.dart';
import 'pages/credentials_page.dart';
import 'pages/fingerprints_page.dart';
import 'pages/settings_page.dart';
import 'widgets/desktop_title_bar.dart';
import 'widgets/fingerprint_enroll_dialog.dart';
import 'widgets/operation_dialog.dart';

class KeeperApp extends StatefulWidget {
  const KeeperApp({super.key, this.desktop = true});
  final bool desktop;
  @override
  State<KeeperApp> createState() => _KeeperAppState();
}

class _KeeperAppState extends State<KeeperApp> with WindowListener {
  backend.Snapshot? _state;
  int _pending = 0;
  backend.CommandKind? _busyKind;
  bool get _busy => _pending > 0;
  bool get _showBusyBar =>
      _closing || (_busy && _busyKind != backend.CommandKind.enrollBio);
  Future<void> _queue = Future<void>.value();
  bool _closing = false;
  String? _error;
  int _page = 0;
  final _search = TextEditingController();
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  String tr(String zh, String en) =>
      _state?.preferences.locale == 'en-US' ? en : zh;

  @override
  void initState() {
    super.initState();
    if (widget.desktop) windowManager.addListener(this);
    _load();
  }

  Future<void> _load() async {
    await _act(backend.CommandKind.initialize);
  }

  Future<void> _dispatch(
    backend.CommandKind kind, {
    String value = '',
    String pin = '',
    String newPin = '',
    String confirmPin = '',
    bool confirmed = false,
    bool enqueue = false,
  }) async {
    if ((_busy && !enqueue) || _closing) {
      throw StateError(tr('请等待当前操作完成', 'Wait for the current operation'));
    }
    setState(() {
      _pending++;
      _busyKind = kind;
      _error = null;
    });
    try {
      final request = _queue.then(
        (_) => backend.dispatch(
          command: backend.Command(
            kind: kind,
            value: value,
            pin: pin,
            newPin: newPin,
            confirmPin: confirmPin,
            confirmed: confirmed,
          ),
        ),
      );
      _queue = request.then<void>((_) {}, onError: (Object _, StackTrace _) {});
      final state = await request;
      if (mounted) setState(() => _state = state);
    } finally {
      if (mounted) {
        setState(() {
          _pending--;
          if (_pending == 0) _busyKind = null;
        });
      }
    }
  }

  Future<void> _act(
    backend.CommandKind kind, {
    String value = '',
    String newPin = '',
    bool enqueue = false,
  }) async {
    try {
      await _dispatch(kind, value: value, newPin: newPin, enqueue: enqueue);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void onWindowClose() async {
    if (_closing) return;
    setState(() => _closing = true);
    try {
      await _queue;
      await backend.dispatch(
        command: const backend.Command(
          kind: backend.CommandKind.shutdown,
          value: '',
          pin: '',
          newPin: '',
          confirmPin: '',
          confirmed: false,
        ),
      );
      await windowManager.destroy();
    } catch (error) {
      if (mounted) {
        setState(() {
          _closing = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.desktop) windowManager.removeListener(this);
    _search.dispose();
    super.dispose();
  }

  Future<void> _prompt(
    BuildContext context,
    backend.CommandKind kind,
    String title, {
    String value = '',
    String? detail,
  }) async {
    if (_busy || _closing) return;
    final inputs = backend.operationInputs(kind: kind);
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => kind == backend.CommandKind.enrollBio
          ? FingerprintEnrollDialog(
              tr: tr,
              onEnroll: () => _dispatch(kind, value: value),
              samples: backend.enrollCaptured,
            )
          : OperationDialog(
              title: title,
              detail: detail,
              changePin: inputs.changePin,
              askPin: inputs.askPin,
              tr: tr,
              onSubmit: (pin, newPin, confirmPin) => _dispatch(
                kind,
                value: value,
                pin: pin,
                newPin: newPin,
                confirmPin: confirmPin,
                confirmed: inputs.requiresConfirmation,
              ),
            ),
    );
    if (!mounted || completed != true) return;
    _messenger.currentState?.showSnackBar(
      SnackBar(content: Text(tr('操作成功', 'Operation completed'))),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FidoKeeper',
    debugShowCheckedModeBanner: false,
    scaffoldMessengerKey: _messenger,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff356859),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorSchemeSeed: const Color(0xff356859),
      brightness: Brightness.dark,
      useMaterial3: true,
    ),
    themeMode: switch (_state?.preferences.theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
    builder: widget.desktop ? VirtualWindowFrameInit() : null,
    home: Builder(
      builder: (context) => Scaffold(
        appBar: widget.desktop
            ? const DesktopTitleBar()
            : AppBar(title: const Text('FidoKeeper')),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _page,
              onDestinationSelected: (index) {
                setState(() => _page = index);
                if (index == 2) {
                  _act(backend.CommandKind.enterFingerprints, enqueue: true);
                }
              },
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.key_outlined),
                  selectedIcon: const Icon(Icons.key),
                  label: Text(tr('认证器', 'Devices')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.password_outlined),
                  selectedIcon: const Icon(Icons.password),
                  label: Text(tr('凭证', 'Credentials')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.fingerprint_outlined),
                  selectedIcon: const Icon(Icons.fingerprint),
                  label: Text(tr('指纹', 'Fingerprints')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: Text(tr('设置', 'Settings')),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  if (_showBusyBar) const LinearProgressIndicator(minHeight: 2),
                  if (_error != null)
                    MaterialBanner(
                      content: Text(_error!),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => _error = null),
                          child: Text(tr('关闭', 'Dismiss')),
                        ),
                      ],
                    ),
                  Expanded(
                    child: switch (_page) {
                      0 => DevicesPage(
                        snapshot: _state,
                        busy: _busy,
                        closing: _closing,
                        tr: tr,
                        onAction: _act,
                        onPrompt: _prompt,
                      ),
                      1 => CredentialsPage(
                        snapshot: _state,
                        busy: _busy,
                        closing: _closing,
                        tr: tr,
                        onAction: _act,
                        onPrompt: _prompt,
                        searchController: _search,
                      ),
                      2 => FingerprintsPage(
                        snapshot: _state,
                        busy: _busy,
                        closing: _closing,
                        tr: tr,
                        onAction: _act,
                        onPrompt: _prompt,
                      ),
                      _ => SettingsPage(
                        snapshot: _state,
                        busy: _busy,
                        closing: _closing,
                        tr: tr,
                        onAction: _act,
                      ),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
