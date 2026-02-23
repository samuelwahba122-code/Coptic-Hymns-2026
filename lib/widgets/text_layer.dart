import 'package:flutter/material.dart';

class TextLayer extends StatelessWidget {
  final String text;
  final String? fontFamily;
  final bool isActive;
  final TextAlign textAlign;

  const TextLayer({
    super.key,
    required this.text,
    this.fontFamily,
    this.isActive = false,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: const ['CopticFont'],
        fontSize: 22,
        height: 1.8,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
        color: isActive ? cs.onSurface : cs.onSurface.withOpacity(0.92),
      ),
    );
  }
}