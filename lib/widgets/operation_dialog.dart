import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';

class OperationDialog extends StatefulWidget {
  const OperationDialog({
    super.key,
    required this.title,
    required this.onSubmit,
    this.detail,
    this.changePin = false,
    this.askPin = true,
  });
  final String title;
  final String? detail;
  final bool changePin;
  final bool askPin;
  final Future<void> Function(String pin, String newPin, String confirmPin)
  onSubmit;

  @override
  State<OperationDialog> createState() => _OperationDialogState();
}

class _OperationDialogState extends State<OperationDialog> {
  final _pin = TextEditingController();
  final _newPin = TextEditingController();
  final _confirm = TextEditingController();
  bool _pending = false;
  String? _error;

  void _clearInputs() {
    _pin.clear();
    _newPin.clear();
    _confirm.clear();
  }

  Future<void> _submit() async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_pin.text, _newPin.text, _confirm.text);
      if (!mounted) return;
      _clearInputs();
      Navigator.pop(context, true);
    } catch (failure) {
      if (!mounted) return;
      _clearInputs();
      setState(() {
        _pending = false;
        _error = failure.toString();
      });
    }
  }

  @override
  void dispose() {
    // 路由返回时退场动画尚未结束，控制器必须随弹窗控件卸载再释放。
    _pin.dispose();
    _newPin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_pending,
      child: AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_pending)
                  // 验证中只保留转圈提示，避免 PIN 等输入还留在画面上。
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            l10n.communicatingWithAuthenticator,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  if (widget.detail != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(widget.detail!),
                    ),
                  if (widget.askPin)
                    _pinField(
                      controller: _pin,
                      label: l10n.devicePin,
                      autofocus: true,
                      onSubmitted: (_) {
                        if (!widget.changePin) _submit();
                      },
                    ),
                  if (widget.changePin) ...[
                    _pinField(
                      controller: _newPin,
                      label: l10n.newPin,
                      autofocus: !widget.askPin,
                    ),
                    _pinField(
                      controller: _confirm,
                      label: l10n.confirmNewPin,
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SelectableText(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: _pending
            ? null
            : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                FilledButton(onPressed: _submit, child: Text(l10n.confirm)),
              ],
      ),
    );
  }

  // PIN 只遮盖输入，不声明为账户密码，避免系统自动填入并耗尽尝试次数。
  TextField _pinField({
    required TextEditingController controller,
    required String label,
    bool autofocus = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: true,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: const <String>[],
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      decoration: InputDecoration(labelText: label),
      onSubmitted: onSubmitted,
    );
  }
}
