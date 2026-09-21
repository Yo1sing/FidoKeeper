import 'package:flutter/material.dart';

/// 与 Rust `COLOR_SEEDS` 保持一致；关闭动态取色时用这些种子生成配色。
const defaultColorSeed = '356859';

const colorPresets = <Color>[
  Color(0xff356859),
  Color(0xff1a73e8),
  Color(0xff6750a4),
  Color(0xff0f766e),
  Color(0xffc2410c),
  Color(0xffbe123c),
];

String colorSeedHex(Color color) =>
    (color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0');

Color colorFromSeedHex(String? hex) {
  final normalized = hex?.toLowerCase();
  if (normalized == null || normalized.length != 6) {
    return const Color(0xff356859);
  }
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return const Color(0xff356859);
  return Color(0xff000000 | value);
}

class ColorPresetButton extends StatelessWidget {
  const ColorPresetButton({
    super.key,
    required this.color,
    required this.selected,
    this.onPressed,
  });

  final Color color;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    final checkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? checkColor : outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: selected
                ? Icon(Icons.check, color: checkColor, size: 22)
                : null,
          ),
        ),
      ),
    );
  }
}
