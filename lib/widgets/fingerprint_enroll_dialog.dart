import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../src/rust/api/keeper.dart' as backend;
import '../ui/callbacks.dart';
import 'fingerprint_enroll_animation.dart';

export 'fingerprint_enroll_animation.dart';

class FingerprintEnrollDialog extends StatefulWidget {
  const FingerprintEnrollDialog({
    super.key,
    required this.onEnroll,
    required this.samples,
    this.onCancel,
  });

  final Future<void> Function() onEnroll;
  final int Function() samples;
  final bool Function()? onCancel;

  @override
  State<FingerprintEnrollDialog> createState() =>
      _FingerprintEnrollDialogState();
}

class _FingerprintEnrollDialogState extends State<FingerprintEnrollDialog> {
  bool _pending = false;
  bool _finished = false;
  bool _closing = false;
  bool _cancelling = false;
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
      _cancelling = false;
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
      if (_cancelling && failure is backend.CommandError && failure.cancelled) {
        Navigator.pop(context, false);
        return;
      }
      setState(() {
        _pending = false;
        _error = backendMessage(failure);
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
    final l10n = context.l10n;
    return PopScope(
      canPop: !_pending && !_finished,
      child: AlertDialog(
        title: Text(l10n.enrollFingerprint),
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
                _cancelling && _pending
                    ? l10n.cancellingEnrollment
                    : _error == null
                    ? l10n.enrollInstruction
                    : l10n.enrollIncomplete,
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
          if (_pending && widget.onCancel != null)
            TextButton(
              onPressed: _cancelling
                  ? null
                  : () {
                      try {
                        if (widget.onCancel!()) {
                          setState(() => _cancelling = true);
                        }
                      } catch (error) {
                        setState(() => _error = error.toString());
                      }
                    },
              child: Text(l10n.cancelEnrollment),
            ),
          if (!_pending && _error != null) ...[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
            FilledButton(onPressed: _start, child: Text(l10n.retry)),
          ],
        ],
      ),
    );
  }
}
