import 'dart:async';

import 'package:flutter/material.dart';

import 'fingerprint_enroll_animation.dart';

export 'fingerprint_enroll_animation.dart';

class FingerprintEnrollDialog extends StatefulWidget {
  const FingerprintEnrollDialog({
    super.key,
    required this.tr,
    required this.onEnroll,
    required this.samples,
  });

  final String Function(String, String) tr;
  final Future<void> Function() onEnroll;
  final int Function() samples;

  @override
  State<FingerprintEnrollDialog> createState() =>
      _FingerprintEnrollDialogState();
}

class _FingerprintEnrollDialogState extends State<FingerprintEnrollDialog> {
  bool _pending = false;
  bool _finished = false;
  bool _closing = false;
  String? _error;
  int _samples = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  void _listen() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted || !_pending) return;
      final n = widget.samples();
      if (n != _samples) setState(() => _samples = n);
    });
  }

  Future<void> _start() async {
    if (_pending) return;
    _poll?.cancel();
    setState(() {
      _pending = true;
      _finished = false;
      _error = null;
      _samples = 0;
    });
    _listen();
    try {
      await widget.onEnroll();
      if (!mounted) return;
      _poll?.cancel();
      setState(() {
        _pending = false;
        _finished = true;
      });
    } catch (failure) {
      if (!mounted) return;
      _poll?.cancel();
      setState(() {
        _pending = false;
        _error = failure.toString();
      });
    }
  }

  Future<void> _closeAfterAnimation() async {
    if (!mounted || !_finished || _closing) return;
    _closing = true;
    // 等最后一帧纹路绘制完成，再启动弹窗退场。
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_pending && !_finished,
      child: AlertDialog(
        title: Text(widget.tr('录入指纹', 'Enroll fingerprint')),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              FingerprintEnrollAnimation(
                samples: _samples,
                complete: _finished,
                failed: _error != null,
                onComplete: _closeAfterAnimation,
              ),
              const SizedBox(height: 20),
              Text(
                _error == null
                    ? widget.tr(
                        '请在安全密钥上按压指纹传感器，每按一次会多显出一段纹路',
                        'Press the sensor on the key. Each press reveals more of the fingerprint.',
                      )
                    : widget.tr(
                        '采样未完成，可以重试。',
                        'Enrollment did not finish. You can try again.',
                      ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SelectableText(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (!_pending && _error != null) ...[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.tr('关闭', 'Close')),
            ),
            FilledButton(
              onPressed: _start,
              child: Text(widget.tr('重试', 'Retry')),
            ),
          ],
        ],
      ),
    );
  }
}
