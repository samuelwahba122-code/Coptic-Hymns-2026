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
    this.textAlign = TextAlign.center, // ✅ default value
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: (fontFamily ?? 'HazzatFont').split(',').first.trim(),
        // fontFamilyFallback: const ['Roboto'],
        fontSize: 42,
        height: 1.5,
        fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
        color: Colors.black,
      ),
    );
  }
}