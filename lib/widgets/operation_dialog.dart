import 'package:flutter/material.dart';

class OperationDialog extends StatefulWidget {
  const OperationDialog({
    super.key,
    required this.title,
    required this.tr,
    required this.onSubmit,
    this.detail,
    this.reset = false,
    this.changePin = false,
    this.askPin = true,
  });
  final String title;
  final String? detail;
  final bool reset;
  final bool changePin;
  final bool askPin;
  final String Function(String, String) tr;
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
                if (widget.detail != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(widget.detail!),
                  ),
                if (!widget.reset && widget.askPin)
                  TextField(
                    controller: _pin,
                    autofocus: true,
                    obscureText: true,
                    enabled: !_pending,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: widget.tr('设备 PIN', 'Device PIN'),
                    ),
                    onSubmitted: (_) {
                      if (!widget.changePin) _submit();
                    },
                  ),
                if (widget.changePin) ...[
                  TextField(
                    controller: _newPin,
                    obscureText: true,
                    enabled: !_pending,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: widget.tr('新 PIN', 'New PIN'),
                    ),
                    autofocus: !widget.askPin,
                  ),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    enabled: !_pending,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: widget.tr('确认新 PIN', 'Confirm new PIN'),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                if (_pending) ...[
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(),
                  Text(
                    widget.tr(
                      '正在与认证器通信，请按设备提示触碰或采样…',
                      'Communicating with the authenticator. Follow its touch or enrollment prompts…',
                    ),
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
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _pending ? null : () => Navigator.pop(context),
            child: Text(widget.tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: _pending ? null : _submit,
            child: Text(widget.tr('确认', 'Confirm')),
          ),
        ],
      ),
    );
  }
}
