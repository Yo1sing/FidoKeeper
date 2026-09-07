import 'package:flutter/material.dart';

Widget actionButton(
  String title,
  VoidCallback onPressed, {
  required bool disabled,
  IconData? icon,
}) => OutlinedButton.icon(
  onPressed: disabled ? null : onPressed,
  icon: Icon(icon ?? Icons.chevron_right, size: 18),
  label: Text(title),
);
