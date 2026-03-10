import 'package:flutter/foundation.dart';

@immutable
class HymnSegment {
  final String type; // franco | coptic | hazzat
  final String value;

  const HymnSegment({
    required this.type,
    required this.value,
  });

  factory HymnSegment.fromJson(Map<String, dynamic> j) => HymnSegment(
        type: (j['type'] as String? ?? 'hazzat').trim().toLowerCase(),
        value: (j['value'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
      };
}

@immutable
class HymnLine {
  final int i;
  final int s;
  final int e;
  final String? image;
  final List<HymnSegment> segments;

  const HymnLine({
    required this.i,
    required this.s,
    required this.e,
    this.image,
    required this.segments,
  });

  int get startMs => s;
  int get endMs => e;

  factory HymnLine.fromJson(Map<String, dynamic> j) {
    final rawSegments = (j['segments'] as List?)
        ?.whereType<Map>()
        .map((e) => HymnSegment.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    List<HymnSegment> builtSegments;

    if (rawSegments != null && rawSegments.isNotEmpty) {
      builtSegments = rawSegments;
    } else {
      final mixed = (j['mixed'] as String?) ?? '';
      final coptic = (j['coptic'] as String?) ?? '';

      // Legacy support: use only for coptic + hazzat lines
      if (mixed.isNotEmpty && coptic.isNotEmpty) {
        builtSegments = splitMixedWithCoptic(mixed, coptic);
      } else {
        builtSegments = [];

        final franco = (j['franco'] as String?) ?? '';
        final legacyCoptic = (j['coptic'] as String?) ?? '';
        final hazzat = (j['hazzat'] as String?) ?? '';
        final text = (j['text'] as String?) ?? '';

        if (franco.isNotEmpty) {
          builtSegments.add(HymnSegment(type: 'franco', value: franco));
        }

        if (legacyCoptic.isNotEmpty) {
          builtSegments.add(HymnSegment(type: 'coptic', value: legacyCoptic));
        }

        if (hazzat.isNotEmpty) {
          builtSegments.add(HymnSegment(type: 'hazzat', value: hazzat));
        }

        // old plain text fallback
        if (builtSegments.isEmpty && text.isNotEmpty) {
          builtSegments.add(HymnSegment(type: 'hazzat', value: text));
        }
      }
    }

    return HymnLine(
      i: ((j['i'] ?? 0) as num).toInt(),
      s: ((j['s'] ?? j['startMs'] ?? 0) as num).toInt(),
      e: ((j['e'] ?? j['endMs'] ?? 0) as num).toInt(),
      image: j['image'] as String?,
      segments: builtSegments,
    );
  }

  Map<String, dynamic> toJson() => {
        'i': i,
        's': s,
        'e': e,
        if (image != null) 'image': image,
        'segments': segments.map((e) => e.toJson()).toList(),
      };
}

/// Legacy helper:
/// Only for old lines where `mixed` contains coptic letters mixed with hazzat
/// and `coptic` contains the plain coptic sequence.
/// Do NOT use this for franco lines.
List<HymnSegment> splitMixedWithCoptic(String mixed, String coptic) {
  final result = <HymnSegment>[];
  final copticChars = coptic.replaceAll(' ', '');

  bool isLikelyCopticChar(String ch) {
    if (ch.trim().isEmpty) return false;
    return copticChars.contains(ch);
  }

  final buffer = StringBuffer();
  String? currentType;

  void flush() {
    if (buffer.isEmpty || currentType == null) return;
    result.add(HymnSegment(type: currentType!, value: buffer.toString()));
    buffer.clear();
  }

  for (final rune in mixed.runes) {
    final ch = String.fromCharCode(rune);

    final nextType = isLikelyCopticChar(ch) ? 'coptic' : 'hazzat';

    if (currentType == null) {
      currentType = nextType;
      buffer.write(ch);
      continue;
    }

    if (currentType == nextType) {
      buffer.write(ch);
    } else {
      flush();
      currentType = nextType;
      buffer.write(ch);
    }
  }

  flush();

  return result;
}

@immutable
class HymnData {
  final String id;
  final String title;
  final String? author;
  final String? fontFamily;
  final String? pdfAsset;
  final int? initialPdfPage;
  final String? audio;
  final List<HymnLine> lines;

  const HymnData({
    required this.id,
    required this.title,
    this.author,
    this.fontFamily,
    this.pdfAsset,
    this.initialPdfPage,
    this.audio,
    required this.lines,
  });

  factory HymnData.fromJson(Map<String, dynamic> j) => HymnData(
        id: (j['id'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        author: j['author'] as String?,
        fontFamily: j['fontFamily'] as String?,
        pdfAsset: j['pdfAsset'] as String?,
        initialPdfPage: (j['initialPdfPage'] as num?)?.toInt(),
        audio: j['audio'] as String?,
        lines: ((j['lines'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => HymnLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (author != null) 'author': author,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (pdfAsset != null) 'pdfAsset': pdfAsset,
        if (initialPdfPage != null) 'initialPdfPage': initialPdfPage,
        if (audio != null) 'audio': audio,
        'lines': lines.map((e) => e.toJson()).toList(),
      };
}