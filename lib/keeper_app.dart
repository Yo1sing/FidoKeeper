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
import 'widgets/closing_dialog.dart';
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
  /// 关闭时等待后端的上限：写入设备的操作不能随手打断，读取类超时就先退出。
  static const _readCloseTimeout = Duration(seconds: 3);
  static const _writeCloseTimeout = Duration(seconds: 15);

  /// 秒关时不显示提示，避免弹窗闪一下。
  static const _closingHintDelay = Duration(milliseconds: 250);
  static const _writeKinds = {
    backend.CommandKind.changePin,
    backend.CommandKind.reset,
    backend.CommandKind.deleteCredential,
    backend.CommandKind.deleteBio,
    backend.CommandKind.renameBio,
    backend.CommandKind.enrollBio,
  };

  backend.Snapshot? _state;
  int _pending = 0;
  backend.CommandKind? _busyKind;

  /// 关闭等待超过阈值后显示的操作，用于向用户说明正在等什么。
  backend.CommandKind? _closingOperation;
  Timer? _closingHint;
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
  bool _settingsOpen = false;
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

  /// 全局字体：简体中文与英文用 SC，繁体中文用 TC。
  String get _fontFamily {
    final locale = resolveAppLocale(
      _localeCode,
      WidgetsBinding.instance.platformDispatcher.locales,
    );
    return locale.languageCode == 'zh' && locale.countryCode == 'TW'
        ? 'HarmonyOS Sans TC'
        : 'HarmonyOS Sans SC';
  }

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
    final kind = _busyKind;
    setState(() => _closing = true);
    // 真的需要等才弹提示，秒关时不要闪一下。
    if (kind != null) {
      _closingHint = Timer(_closingHintDelay, () {
        if (mounted && _closing) setState(() => _closingOperation = kind);
      });
    }
    try {
      // 关闭必须先通知后端取消，不能排在正在等待采样的操作之后。
      await backend
          .dispatch(
            command: const backend.Command(
              kind: backend.CommandKind.shutdown,
              value: '',
              pin: '',
              newPin: '',
              confirmPin: '',
              confirmed: false,
            ),
          )
          .timeout(
            _writeKinds.contains(kind) ? _writeCloseTimeout : _readCloseTimeout,
          );
    } on TimeoutException {
      // 设备无响应时也要退出：写操作多等一会儿，读取类超时就直接关，
      // 设备句柄由进程退出时回收。
    } catch (error) {
      if (mounted) {
        setState(() {
          _closing = false;
          _closingOperation = null;
          _error = error.toString();
        });
      }
      return;
    }
    await windowManager.destroy();
  }

  @override
  void dispose() {
    for (final subscription in _exitSignals) {
      subscription.cancel();
    }
    _closingHint?.cancel();
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

  void _openSettings() {
    if (_settingsOpen || _closing) return;
    setState(() => _settingsOpen = true);
  }

  void _closeSettings() {
    if (!_settingsOpen) return;
    setState(() => _settingsOpen = false);
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
        _ => DevicesPage(
          snapshot: _state,
          busy: _busy,
          scanning: _scanningAuthenticators,
          closing: _closing,
          onAction: _act,
          onPrompt: _prompt,
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
    return _pageWithError(pages);
  }

  Widget _pageWithError(Widget page) {
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
        Expanded(child: page),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FidoKeeper',
    debugShowCheckedModeBanner: false,
    scaffoldMessengerKey: _messenger,
    theme: ThemeData(
      fontFamily: _fontFamily,
      colorSchemeSeed: const Color(0xff356859),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      fontFamily: _fontFamily,
      colorSchemeSeed: const Color(0xff356859),
      brightness: Brightness.dark,
      useMaterial3: true,
    ),
    themeMode: _themeMode,
    locale: _appLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      // 关闭提示挂在 builder 上：位于 Navigator 之上，盖住所有对话框，
      // 也不需要像 showDialog 那样在取消关闭时手动退场。
      final framed = widget.desktop && child != null
          ? VirtualWindowFrameInit()(context, child)
          : child;
      final closingOperation = _closingOperation;
      return Stack(
        children: [
          ?framed,
          if (closingOperation != null)
            ClosingDialog(operation: closingOperation),
        ],
      );
    },
    home: Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final l10n = context.l10n;
        final compact = !widget.desktop;
        final nav = AppSidebar(
          selectedIndex: _page,
          bottom: compact,
          onDestinationSelected: _selectPage,
          onOpenSettings: _openSettings,
          onScanDevices: () => _act(backend.CommandKind.scan),
          scanEnabled: !_busy && !_closing,
          scanning: _scanningAuthenticators,
        );
        final mainContent = compact
            ? _contentColumn(context, padForBottomNav: true)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  nav,
                  Expanded(child: _contentColumn(context)),
                ],
              );
        final settingsContent = _pageWithError(
          SettingsPage(
            snapshot: _state,
            busy: _busy,
            closing: _closing,
            onAction: _act,
          ),
        );
        return PopScope(
          canPop: !_settingsOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _settingsOpen) _closeSettings();
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
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
              extendBody: compact && !_settingsOpen,
              appBar: widget.desktop
                  ? DesktopTitleBar(
                      onBack: _settingsOpen ? _closeSettings : null,
                    )
                  : _settingsOpen
                  ? AppBar(
                      title: Text(l10n.navSettings),
                      leading: _AnimatedBackButton(onPressed: _closeSettings),
                    )
                  : AppBar(title: const Text('FidoKeeper')),
              bottomNavigationBar: compact && !_settingsOpen
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  reverseDuration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final isSettings =
                        child.key == const ValueKey('settings-page');
                    final beginOffset = isSettings
                        ? const Offset(0.035, 0)
                        : const Offset(-0.035, 0);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: beginOffset,
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _settingsOpen
                      ? KeyedSubtree(
                          key: const ValueKey('settings-page'),
                          child: settingsContent,
                        )
                      : KeyedSubtree(
                          key: const ValueKey('main-page'),
                          child: mainContent,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _AnimatedBackButton extends StatefulWidget {
  const _AnimatedBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_AnimatedBackButton> createState() => _AnimatedBackButtonState();
}

class _AnimatedBackButtonState extends State<_AnimatedBackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(-0.45, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: _offset,
        child: BackButton(onPressed: widget.onPressed),
      ),
    );
  }
}
