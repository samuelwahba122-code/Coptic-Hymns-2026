import 'package:flutter/foundation.dart';

@immutable
class HymnSegment {
  /// "franco" | "hazzat" | "coptic"
  final String type;
  final String value;

  const HymnSegment({required this.type, required this.value});

  factory HymnSegment.fromJson(Map<String, dynamic> j) => HymnSegment(
        type: (j['type'] as String?)?.trim().toLowerCase() ?? 'hazzat',
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

  // canonical timing fields
  final int s;
  final int e;

  final String? image;

  /// Always populated (either from JSON "segments" or auto-built from legacy fields).
  final List<HymnSegment> segments;

  const HymnLine({
    required this.i,
    required this.s,
    required this.e,
    this.image,
    required this.segments,
  });

  // ---------- compatibility getters (what your screen expects) ----------
  int get startMs => s;
  int get endMs => e;

  /// Concatenated "franco" segments (legacy compatibility).
  String? get franco {
    final parts = segments
        .where((x) => x.type == 'franco')
        .map((x) => x.value.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  /// Legacy "text" getter:
  /// - returns concatenated Hazzat + Coptic (so list UI sees text even if only coptic exists)
  /// - keep this if your UI checks line.text for visibility
  String? get text {
    final parts = segments
        .where((x) => x.type == 'hazzat' || x.type == 'coptic')
        .map((x) => x.value)
        .toList();
    final out = parts.join('');
    final trimmed = out.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Optional explicit getter if you want to use it later.
  String? get coptic {
    final parts = segments
        .where((x) => x.type == 'coptic')
        .map((x) => x.value)
        .toList();
    final out = parts.join('');
    final trimmed = out.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  // ---------------------------------------------------------------------

  factory HymnLine.fromJson(Map<String, dynamic> j) {
    // Prefer new format: "segments"
    final rawSegments = j['segments'];
    List<HymnSegment> segs = [];

    if (rawSegments is List) {
      segs = rawSegments
          .whereType<Map>()
          .map((m) => HymnSegment.fromJson(Map<String, dynamic>.from(m)))
          .where((seg) => seg.value.trim().isNotEmpty)
          .toList(growable: false);
    } else {
      // Fallback legacy format: "franco" + ("hazzat"/"text") + ("coptic")
      final legacyFranco = (j['franco'] as String?)?.trim();
      final legacyHazzat =
          (j['text'] as String?)?.trim() ?? (j['hazzat'] as String?)?.trim();
      final legacyCoptic = (j['coptic'] as String?)?.trim();

      final tmp = <HymnSegment>[];

      if (legacyFranco != null && legacyFranco.isNotEmpty) {
        tmp.add(HymnSegment(type: 'franco', value: legacyFranco));
      }
      if (legacyCoptic != null && legacyCoptic.isNotEmpty) {
        tmp.add(HymnSegment(type: 'coptic', value: legacyCoptic));
      }
      if (legacyHazzat != null && legacyHazzat.isNotEmpty) {
        tmp.add(HymnSegment(type: 'hazzat', value: legacyHazzat));
      }

      segs = tmp;
    }

    return HymnLine(
      i: ((j['i'] ?? 0) as num).toInt(),
      s: ((j['s'] ?? j['startMs'] ?? 0) as num).toInt(),
      e: ((j['e'] ?? j['endMs'] ?? 0) as num).toInt(),
      image: (j['image'] as String?)?.trim().isEmpty ?? true
          ? null
          : (j['image'] as String?)?.trim(),
      segments: segs,
    );
  }

  Map<String, dynamic> toJson() => {
        'i': i,
        's': s,
        'e': e,
        if (image != null) 'image': image,
        'segments': segments.map((x) => x.toJson()).toList(),
      };
}

@immutable
class HymnData {
  final String id;
  final String title;

  /// Your Hazzat/notation font family (used for segment type "hazzat").
  final String fontFamily;

  final String? author;

  // canonical field in JSON is "audio"
  final String audio;

  // canonical field in JSON could be "pdf" (or legacy "pdfAsset")
  final String? pdf;

  final List<HymnLine> lines;

  const HymnData({
    required this.id,
    required this.title,
    required this.fontFamily,
    required this.audio,
    required this.lines,
    this.author,
    this.pdf,
  });

  // ---------- compatibility getters (what your screen expects) ----------
  String get audioAsset => audio;
  String? get pdfAsset => pdf;
  // ---------------------------------------------------------------------

  factory HymnData.fromJson(Map<String, dynamic> j) {
    final rawLines = (j['lines'] as List?) ?? const [];

    return HymnData(
      id: (j['id'] as String?) ?? '',
      title: (j['title'] as String?) ?? '',
      fontFamily: (j['fontFamily'] as String?) ?? 'HazzatFont',
      author: j['author'] as String?,
      audio: (j['audio'] as String?) ?? (j['audioAsset'] as String?) ?? '',
      pdf: (j['pdf'] as String?) ?? (j['pdfAsset'] as String?),
      lines: rawLines
          .whereType<Map>()
          .map((m) => HymnLine.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'fontFamily': fontFamily,
        if (author != null) 'author': author,
        'audio': audio,
        if (pdf != null) 'pdf': pdf,
        'lines': lines.map((x) => x.toJson()).toList(),
      };
}