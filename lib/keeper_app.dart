import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'src/rust/api/keeper.dart' as backend;
import 'src/rust/api/models.dart';
import 'l10n/locale_preference.dart';
import 'pages/devices_page.dart';
import 'pages/credentials_page.dart';
import 'pages/fingerprints_page.dart';
import 'pages/settings_page.dart';
import 'widgets/app_sidebar.dart';
import 'widgets/desktop_title_bar.dart';
import 'widgets/fingerprint_enroll_dialog.dart';
import 'widgets/operation_dialog.dart';
import 'widgets/sliding_page_switcher.dart';

class KeeperApp extends StatefulWidget {
  const KeeperApp({super.key, this.desktop = true, this.preferences});
  final bool desktop;
  final Preferences? preferences;
  @override
  State<KeeperApp> createState() => _KeeperAppState();
}

class _KeeperAppState extends State<KeeperApp> with WindowListener {
  backend.Snapshot? _state;
  int _pending = 0;
  backend.CommandKind? _busyKind;
  bool get _busy => _pending > 0;
  bool get _scanningAuthenticators =>
      _busy &&
      (_busyKind == backend.CommandKind.scan ||
          _busyKind == backend.CommandKind.initialize);
  Future<void> _queue = Future<void>.value();
  bool _closing = false;
  final List<StreamSubscription<ProcessSignal>> _exitSignals = [];
  String? _error;
  int _page = 0;
  final _search = TextEditingController();
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// 跟随系统时为 null，交给 MaterialApp 按系统语言解析。
  Locale? get _appLocale => localeFromPreference(_localeCode);

  String? get _localeCode =>
      _state?.preferences.locale ?? widget.preferences?.locale;

  /// 错误条、提示语在界面之外取文案，跟随系统时按系统语言解析。
  AppLocalizations get _l10n => lookupAppLocalizations(
    resolveAppLocale(
      _localeCode,
      WidgetsBinding.instance.platformDispatcher.locales,
    ),
  );

  ThemeMode get _themeMode =>
      switch (_state?.preferences.theme ?? widget.preferences?.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  @override
  void initState() {
    super.initState();
    if (widget.desktop) {
      windowManager.addListener(this);
      if (Platform.isLinux) {
        for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
          _exitSignals.add(signal.watch().listen((_) => onWindowClose()));
        }
      }
    }
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
      throw StateError(_l10n.waitForCurrentOperation);
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
      // 关闭必须先通知后端取消，不能排在正在等待采样的操作之后。
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
    for (final subscription in _exitSignals) {
      subscription.cancel();
    }
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
              onEnroll: () => _dispatch(kind, value: value),
              samples: backend.enrollCaptured,
              onCancel: backend.cancelEnrollment,
            )
          : OperationDialog(
              title: title,
              detail: detail,
              changePin: inputs.changePin,
              askPin: inputs.askPin,
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
      SnackBar(content: Text(_l10n.operationCompleted)),
    );
  }

  void _selectPage(int index) {
    setState(() => _page = index);
    // 移动端无独立刷新按钮，点「认证器」即扫描。
    if (!widget.desktop && index == 0 && !_busy && !_closing) {
      _act(backend.CommandKind.scan);
    }
    if (index == 2) {
      _act(backend.CommandKind.enterFingerprints, enqueue: true);
    }
  }

  Widget _contentColumn(BuildContext context, {bool padForBottomNav = false}) {
    Widget pages = SlidingPageSwitcher(
      index: _page,
      child: switch (_page) {
        0 => DevicesPage(
          snapshot: _state,
          busy: _busy,
          scanning: _scanningAuthenticators,
          closing: _closing,
          onAction: _act,
          onPrompt: _prompt,
        ),
        1 => CredentialsPage(
          snapshot: _state,
          busy: _busy,
          closing: _closing,
          onAction: _act,
          onPrompt: _prompt,
          searchController: _search,
        ),
        2 => FingerprintsPage(
          snapshot: _state,
          busy: _busy,
          closing: _closing,
          onAction: _act,
          onPrompt: _prompt,
        ),
        _ => SettingsPage(
          snapshot: _state,
          busy: _busy,
          closing: _closing,
          onAction: _act,
        ),
      },
    );
    if (padForBottomNav) {
      final mq = MediaQuery.of(context);
      pages = MediaQuery(
        data: mq.copyWith(
          padding: mq.padding.copyWith(
            bottom: mq.padding.bottom + bottomNavOverlayExtent,
          ),
        ),
        child: pages,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          MaterialBanner(
            content: Text(_error!),
            actions: [
              TextButton(
                onPressed: () => setState(() => _error = null),
                child: Text(_l10n.dismiss),
              ),
            ],
          ),
        Expanded(child: pages),
      ],
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
    themeMode: _themeMode,
    locale: _appLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: widget.desktop ? VirtualWindowFrameInit() : null,
    home: Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final compact = !widget.desktop;
        final nav = AppSidebar(
          selectedIndex: _page,
          bottom: compact,
          onDestinationSelected: _selectPage,
          onScanDevices: () => _act(backend.CommandKind.scan),
          scanEnabled: !_busy && !_closing,
          scanning: _scanningAuthenticators,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            systemNavigationBarIconBrightness:
                scheme.brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: scheme.surface,
            extendBody: compact,
            appBar: widget.desktop
                ? const DesktopTitleBar()
                : AppBar(title: const Text('FidoKeeper')),
            bottomNavigationBar: compact
                ? Material(color: Colors.transparent, child: nav)
                : null,
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surface,
                    Color.alphaBlend(
                      scheme.primary.withValues(alpha: 0.08),
                      scheme.surface,
                    ),
                    Color.alphaBlend(
                      scheme.tertiary.withValues(alpha: 0.12),
                      scheme.surfaceContainerLow,
                    ),
                  ],
                ),
              ),
              child: compact
                  ? _contentColumn(context, padForBottomNav: true)
                  : Row(
                      children: [
                        nav,
                        Expanded(child: _contentColumn(context)),
                      ],
                    ),
            ),
          ),
        );
      },
    ),
  );
}
