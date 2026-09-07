import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/rust/api/keeper.dart' as backend;
import 'src/rust/api/models.dart';
import 'widgets/desktop_title_bar.dart';
import 'widgets/operation_dialog.dart';

class KeeperApp extends StatefulWidget {
  const KeeperApp({super.key, this.desktop = true});
  final bool desktop;
  @override
  State<KeeperApp> createState() => _KeeperAppState();
}

class _KeeperAppState extends State<KeeperApp> with WindowListener {
  backend.Snapshot? _state;
  bool _busy = false;
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
    await _act(backend.CommandKind.load);
    await _act(backend.CommandKind.scan);
  }

  Future<void> _dispatch(
    backend.CommandKind kind, {
    String value = '',
    String pin = '',
    String newPin = '',
    String confirmPin = '',
    bool confirmed = false,
  }) async {
    if (_busy || _closing) {
      throw StateError(tr('请等待当前操作完成', 'Wait for the current operation'));
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = await backend.dispatch(
        command: backend.Command(
          kind: kind,
          value: value,
          pin: pin,
          newPin: newPin,
          confirmPin: confirmPin,
          confirmed: confirmed,
        ),
      );
      if (mounted) setState(() => _state = state);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act(backend.CommandKind kind, {String value = ''}) async {
    try {
      await _dispatch(kind, value: value);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void onWindowClose() async {
    if (_closing) return;
    setState(() => _closing = true);
    try {
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
    bool reset = false,
    bool changePin = false,
  }) async {
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OperationDialog(
        title: title,
        detail: detail,
        reset: reset,
        changePin: changePin,
        tr: tr,
        onSubmit: (pin, newPin, confirmPin) => _dispatch(
          kind,
          value: value,
          pin: pin,
          newPin: newPin,
          confirmPin: confirmPin,
          confirmed: true,
        ),
      ),
    );
    if (!mounted || completed != true) return;
    _messenger.currentState?.showSnackBar(
      SnackBar(content: Text(tr('操作成功', 'Operation completed'))),
    );
  }

  Widget _button(String title, VoidCallback callback, {IconData? icon}) =>
      OutlinedButton.icon(
        onPressed: _busy || _closing ? null : callback,
        icon: Icon(icon ?? Icons.chevron_right, size: 18),
        label: Text(title),
      );

  Widget _devices(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        tr('认证器', 'Authenticators'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                tr(
                  '插入安全密钥后重新扫描。所有操作均在本机完成。',
                  'Insert a security key and scan. All operations stay on this computer.',
                ),
              ),
              _button(
                tr('重新扫描', 'Scan again'),
                () => _act(backend.CommandKind.scan),
                icon: Icons.refresh,
              ),
            ],
          ),
        ),
      ),
      if (_state != null && _state!.devices.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr(
              '未发现可用认证器；请检查连接、设备权限或隐藏列表。',
              'No authenticators found. Check connections, device permissions, or hidden devices.',
            ),
          ),
        ),
      for (final device in _state?.devices ?? <DeviceSummary>[])
        Card(
          child: ListTile(
            leading: const Icon(Icons.key),
            title: Text(device.label),
            subtitle: _state?.active?.path == device.path
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(Icons.circle, color: Colors.green, size: 8),
                  )
                : null,
            onTap: _busy || _closing
                ? null
                : () => _prompt(
                    context,
                    backend.CommandKind.connect,
                    tr('连接认证器', 'Connect authenticator'),
                    value: device.path,
                    detail: device.label,
                  ),
            trailing: PopupMenuButton<String>(
              enabled: !_busy && !_closing,
              onSelected: (action) {
                switch (action) {
                  case 'details':
                    showDialog<void>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(device.label),
                        content: SelectableText(
                          '${device.path}\n${device.protocol}\n${tr('凭证管理', 'Credential management')}: ${device.credentialManagement}\nPIN: ${device.pin}\n${tr('指纹', 'Fingerprint')}: ${device.fingerprint}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: Text(tr('关闭', 'Close')),
                          ),
                        ],
                      ),
                    );
                  case 'disconnect':
                    _act(backend.CommandKind.disconnect);
                  case 'hide':
                    _act(backend.CommandKind.hide_, value: device.path);
                  case 'reset':
                    _prompt(
                      context,
                      backend.CommandKind.reset,
                      tr('重置认证器', 'Reset authenticator'),
                      value: device.path,
                      reset: true,
                      detail:
                          '${device.label}\n${tr('此操作会永久清除全部凭证、PIN 和指纹，无法撤销。请重新插入设备后立即确认，并按设备提示触碰。', 'This permanently erases all credentials, PIN and fingerprints. Reinsert the device, confirm immediately, then touch it as prompted.')}',
                    );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'details',
                  child: Text(tr('详情', 'Details')),
                ),
                if (_state?.active?.path == device.path)
                  PopupMenuItem(
                    value: 'disconnect',
                    child: Text(tr('断开连接', 'Disconnect')),
                  ),
                PopupMenuItem(
                  value: 'hide',
                  child: Text(tr('隐藏设备', 'Hide device')),
                ),
                PopupMenuItem(
                  value: 'reset',
                  child: Text(tr('重置设备…', 'Reset device…')),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _credentials(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        tr('凭证管理', 'Credentials'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      Text(
        _state?.active?.label ??
            tr('请先在认证器页面连接设备', 'Connect a device from Authenticators first'),
      ),
      if (_state?.active != null) ...[
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _button(
              tr('读取凭证', 'Read credentials'),
              () => _prompt(
                context,
                backend.CommandKind.listCredentials,
                tr('读取凭证', 'Read credentials'),
              ),
              icon: Icons.refresh,
            ),
            _button(
              tr('更改 PIN', 'Change PIN'),
              () => _prompt(
                context,
                backend.CommandKind.changePin,
                tr('更改 PIN', 'Change PIN'),
                changePin: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${tr('已用', 'Used')}: ${_state!.existing} · ${tr('剩余', 'Remaining')}: ${_state!.remaining}',
        ),
        TextField(
          controller: _search,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: tr(
              '搜索网站或用户，回车筛选',
              'Search website or user, press Enter',
            ),
            prefixIcon: const Icon(Icons.search),
          ),
          onSubmitted: (query) =>
              _act(backend.CommandKind.filter, value: query),
        ),
        const SizedBox(height: 16),
        for (final credential in _state!.credentials)
          Card(
            child: ListTile(
              title: Text(credential.rpName),
              subtitle: Text(
                '${credential.rpId}\n${credential.userName} ${credential.userDisplayName}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: tr('删除凭证', 'Delete credential'),
                onPressed: _busy
                    ? null
                    : () => _prompt(
                        context,
                        backend.CommandKind.deleteCredential,
                        tr('永久删除凭证', 'Permanently delete credential'),
                        value: credential.id,
                        detail:
                            '${credential.rpId}\n${credential.userName}\n${tr('删除后可能无法再登录此账号，操作无法撤销。', 'You may lose access to this account. This cannot be undone.')}',
                      ),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
        if (_state!.credentials.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tr('没有匹配的可发现凭证', 'No matching discoverable credentials'),
            ),
          ),
      ],
    ],
  );

  Widget _fingerprints(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        tr('指纹管理', 'Fingerprints'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      if (_state?.active?.fingerprint != true)
        Text(
          tr(
            '请连接支持指纹的认证器',
            'Connect an authenticator with fingerprint support',
          ),
        )
      else ...[
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _button(
              tr('读取指纹', 'Read fingerprints'),
              () => _prompt(
                context,
                backend.CommandKind.listBio,
                tr('读取指纹', 'Read fingerprints'),
              ),
            ),
            _button(
              tr('录入指纹', 'Enroll fingerprint'),
              () => _prompt(
                context,
                backend.CommandKind.enrollBio,
                tr('录入指纹', 'Enroll fingerprint'),
                detail: tr(
                  '提交后请在设备上重复采样。完成后重新读取指纹列表。',
                  'Touch the sensor repeatedly when prompted. Refresh the list after enrollment.',
                ),
              ),
            ),
          ],
        ),
        for (final template in _state!.templates)
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(template.name.isEmpty ? template.id : template.name),
            trailing: IconButton(
              onPressed: _busy
                  ? null
                  : () => _prompt(
                      context,
                      backend.CommandKind.deleteBio,
                      tr('永久删除指纹', 'Permanently delete fingerprint'),
                      value: template.id,
                      detail: template.name.isEmpty
                          ? template.id
                          : template.name,
                    ),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
      ],
    ],
  );

  Widget _settings(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        tr('设置', 'Settings'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: _state?.preferences.theme ?? 'system',
        decoration: InputDecoration(labelText: tr('主题', 'Theme')),
        items: [
          DropdownMenuItem(value: 'system', child: Text(tr('跟随系统', 'System'))),
          DropdownMenuItem(value: 'light', child: Text(tr('浅色', 'Light'))),
          DropdownMenuItem(value: 'dark', child: Text(tr('深色', 'Dark'))),
        ],
        onChanged: _busy
            ? null
            : (value) {
                if (value != null) {
                  _act(backend.CommandKind.theme, value: value);
                }
              },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: _state?.preferences.locale ?? 'zh-CN',
        decoration: InputDecoration(labelText: tr('语言', 'Language')),
        items: const [
          DropdownMenuItem(value: 'zh-CN', child: Text('简体中文')),
          DropdownMenuItem(value: 'en-US', child: Text('English')),
        ],
        onChanged: _busy
            ? null
            : (value) {
                if (value != null) {
                  _act(backend.CommandKind.locale, value: value);
                }
              },
      ),
      const SizedBox(height: 24),
      Text(tr('已隐藏的认证器', 'Hidden authenticators')),
      for (final device in _state?.preferences.hiddenAuthenticators ?? [])
        ListTile(
          title: Text(device.label),
          trailing: _button(
            tr('恢复显示', 'Show again'),
            () => _act(backend.CommandKind.unhide, value: device.path),
          ),
        ),
    ],
  );

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
        body: Column(
          children: [
            if (_busy || _closing) const LinearProgressIndicator(minHeight: 2),
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
                0 => _devices(context),
                1 => _credentials(context),
                2 => _fingerprints(context),
                _ => _settings(context),
              },
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _page,
          onDestinationSelected: (index) => setState(() => _page = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.key),
              label: tr('认证器', 'Devices'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.password),
              label: tr('凭证', 'Credentials'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.fingerprint),
              label: tr('指纹', 'Fingerprints'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              label: tr('设置', 'Settings'),
            ),
          ],
        ),
      ),
    ),
  );
}
