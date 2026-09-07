import 'package:flutter/widgets.dart';

import '../src/rust/api/keeper.dart' as backend;

typedef Translate = String Function(String zh, String en);

typedef RunAction = Future<void> Function(
  backend.CommandKind kind, {
  String value,
});

typedef PromptOperation = Future<void> Function(
  BuildContext context,
  backend.CommandKind kind,
  String title, {
  String value,
  String? detail,
  bool reset,
  bool changePin,
});
