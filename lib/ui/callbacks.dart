import 'package:flutter/widgets.dart';

import '../src/rust/api/keeper.dart' as backend;

typedef RunAction = Future<void> Function(
  backend.CommandKind kind, {
  String value,
  String newPin,
  String name,
});

/// 桥接错误带有独立的取消标记，展示时只用消息本身。
String backendMessage(Object error) =>
    error is backend.CommandError ? error.message : error.toString();

typedef PromptOperation = Future<void> Function(
  BuildContext context,
  backend.CommandKind kind,
  String title, {
  String value,
  String? detail,
});
