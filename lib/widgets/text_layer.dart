import 'package:flutter/material.dart';
import '../models/hymn_models.dart';

class TextLayer extends StatelessWidget {
  final List<HymnSegment> segments;
  final String hazzatFontFamily;
  final String copticFontFamily;
  final String francoFontFamily;
  final bool isActive;
  final TextAlign textAlign;
  final double fontSize;

  const TextLayer({
    super.key,
    required this.segments,
    this.hazzatFontFamily = 'HazzatFont',
    this.copticFontFamily = 'CopticFont',
    this.francoFontFamily = 'Roboto',
    this.isActive = false,
    this.textAlign = TextAlign.center,
    this.fontSize = 42,
  });

  TextStyle _styleFor(String type) {
    final t = type.toLowerCase();

    switch (t) {
      case 'franco':
        return TextStyle(
          fontFamily: francoFontFamily,
          leadingDistribution: TextLeadingDistribution.even,
          letterSpacing: 4.0,
          wordSpacing: 8.0,
          height: 1.45,
          fontSize: fontSize * 0.8,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
          color: const Color(0xFF111111),
        );

      case 'coptic':
        return TextStyle(
          fontFamily: copticFontFamily,
          leadingDistribution: TextLeadingDistribution.even,
          letterSpacing: 4.0,
          wordSpacing: 8.0,
          fontSize: fontSize * 0.92,
          height: 1.50,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
          color: const Color(0xFF111111),
        );

      case 'hazzat':
      default:
        return TextStyle(
          fontFamily: hazzatFontFamily,
          leadingDistribution: TextLeadingDistribution.even,
          letterSpacing: 2.0,
          wordSpacing: 8.0,
          fontSize: fontSize,
          height: 1.35,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
          color: const Color(0xFF111111),
        );
    }
  }

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];

    for (final seg in segments) {
      final value = seg.value;
      if (value.trim().isEmpty) continue;

      spans.add(
        TextSpan(
          text: value,
          style: _styleFor(seg.type),
        ),
      );
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final spans = _buildSpans();

    return SizedBox(
      width: double.infinity,
      child: RichText(
        textAlign: textAlign,
        text: TextSpan(children: spans),
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
    );
  }
}