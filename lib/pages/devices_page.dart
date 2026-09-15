import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../src/rust/api/keeper.dart' as backend;
import '../src/rust/api/models.dart';
import '../ui/callbacks.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({
    super.key,
    required this.snapshot,
    required this.busy,
    required this.scanning,
    required this.closing,
    required this.tr,
    required this.onAction,
    required this.onPrompt,
  });

  final backend.Snapshot? snapshot;
  final bool busy;
  final bool scanning;
  final bool closing;
  final Translate tr;
  final RunAction onAction;
  final PromptOperation onPrompt;

  bool get _locked => busy || closing;

  @override
  Widget build(BuildContext context) {
    final devices = snapshot?.devices ?? const <DeviceSummary>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        const targetWidth = 280.0;
        final padding = constraints.maxWidth >= 720 ? 28.0 : 16.0;
        final inner = math.max(0.0, constraints.maxWidth - padding * 2);
        final columns = math.max(
          1,
          (inner / (targetWidth + gap)).floor().clamp(1, 4),
        );
        final cardWidth = columns == 1
            ? math.min(inner, targetWidth)
            : (inner - gap * (columns - 1)) / columns;

        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 20, padding, 24),
              child: snapshot != null && devices.isEmpty
                  ? _EmptyState(tr: tr)
                  : SizedBox(
                      width: inner,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          alignment: WrapAlignment.start,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: [
                            for (final device in devices)
                              SizedBox(
                                width: cardWidth,
                                child: _DeviceCard(
                                  device: device,
                                  connected:
                                      snapshot?.active?.path == device.path,
                                  locked: _locked,
                                  tr: tr,
                                  onConnect: () => onPrompt(
                                    context,
                                    backend.CommandKind.connect,
                                    tr('选择认证器', 'Select authenticator'),
                                    value: device.path,
                                    detail: device.label,
                                  ),
                                  onDisconnect: () =>
                                      onAction(backend.CommandKind.disconnect),
                                  onHide: () => onAction(
                                    backend.CommandKind.hide_,
                                    value: device.path,
                                  ),
                                  onReset: () => onPrompt(
                                    context,
                                    backend.CommandKind.reset,
                                    tr('重置认证器', 'Reset authenticator'),
                                    value: device.path,
                                    detail:
                                        '${device.label}\n${tr('此操作会永久清除全部凭证、PIN 和指纹，无法撤销。请重新插入设备后立即确认，并按设备提示触碰。', 'This permanently erases all credentials, PIN and fingerprints. Reinsert the device, confirm immediately, then touch it as prompted.')}',
                                  ),
                                  onDetails: () =>
                                      _showDetails(context, device),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (scanning)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface
                      .withValues(alpha: 0.64),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showDetails(BuildContext context, DeviceSummary device) {
    final transport = device.transport;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        Widget row(String label, String value, {bool selectable = false}) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                selectable
                    ? SelectableText(value)
                    : Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
              ],
            ),
          );
        }

        final supported = tr('支持', 'Supported');
        final unsupported = tr('不支持', 'Not supported');

        return AlertDialog(
          title: Text(device.label),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row(tr('传输', 'Transport'), _transportLabel(tr, transport)),
                  row(tr('协议', 'Protocol'), device.protocol),
                  row(tr('路径', 'Path'), device.path, selectable: true),
                  row(
                    tr('凭证管理', 'Credential management'),
                    device.credentialManagement ? supported : unsupported,
                  ),
                  row('PIN', device.pin ? supported : unsupported),
                  row(
                    tr('指纹', 'Fingerprint'),
                    device.fingerprint ? supported : unsupported,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('关闭', 'Close')),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tr});

  final Translate tr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Glyph(icon: Icons.usb, color: scheme.primary),
                const SizedBox(width: 12),
                _Glyph(icon: Icons.nfc, color: scheme.tertiary),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              tr(
                '等待插入 USB 密钥或贴上 NFC 密钥',
                'Insert a USB key or hold an NFC key',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                '未发现可用认证器；请检查连接、设备权限或隐藏列表。',
                'No authenticators found. Check connections, device permissions, or hidden devices.',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 28, color: color),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.connected,
    required this.locked,
    required this.tr,
    required this.onConnect,
    required this.onDisconnect,
    required this.onHide,
    required this.onReset,
    required this.onDetails,
  });

  final DeviceSummary device;
  final bool connected;
  final bool locked;
  final Translate tr;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onHide;
  final VoidCallback onReset;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final transport = device.transport;

    return Material(
      color: connected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: connected
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outlineVariant,
          width: connected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: locked || connected ? null : onConnect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: connected
                        ? scheme.primary.withValues(alpha: 0.16)
                        : scheme.surfaceContainerHighest,
                    child: Icon(
                      _transportIcon(transport),
                      color: connected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: tr('更多操作', 'More actions'),
                    enabled: !locked,
                    onSelected: (action) {
                      switch (action) {
                        case 'details':
                          onDetails();
                        case 'disconnect':
                          onDisconnect();
                        case 'hide':
                          onHide();
                        case 'reset':
                          onReset();
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'details',
                        child: Text(tr('详情', 'Details')),
                      ),
                      if (connected)
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
                        child: Text(
                          tr('重置设备…', 'Reset device…'),
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                device.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                connected
                    ? tr('已解锁', 'Unlocked')
                    : tr('轻触以选择并输入 PIN', 'Tap to select and enter PIN'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: connected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    icon: _transportIcon(transport),
                    label: _transportLabel(tr, transport),
                  ),
                  _MetaChip(icon: Icons.hub_outlined, label: device.protocol),
                  if (device.pin)
                    _MetaChip(icon: Icons.pin_outlined, label: 'PIN'),
                  if (device.credentialManagement)
                    _MetaChip(
                      icon: Icons.password_outlined,
                      label: tr('凭证管理', 'Credential management'),
                    ),
                  if (device.fingerprint)
                    _MetaChip(
                      icon: Icons.fingerprint,
                      label: tr('指纹', 'Fingerprint'),
                    ),
                ],
              ),
              if (connected) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: locked ? null : onDisconnect,
                    child: Text(tr('断开连接', 'Disconnect')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16, color: scheme.onSecondaryContainer),
      label: Text(label),
      backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.7),
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelStyle: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: scheme.onSecondaryContainer),
    );
  }
}

IconData _transportIcon(Transport transport) => switch (transport) {
  Transport.usb => Icons.usb,
  Transport.nfc => Icons.nfc,
  Transport.hid => Icons.key,
};

String _transportLabel(Translate tr, Transport transport) =>
    switch (transport) {
      Transport.usb => 'USB',
      Transport.nfc => 'NFC',
      Transport.hid => tr('本机 HID', 'Local HID'),
    };
