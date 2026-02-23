class HymnLine {
  /// Optional line image (for extracted PNG line images).
  final String? image;

  /// Optional text (for Hazzat/Coptic font rendering).
  final String? text;

  /// Start time in milliseconds.
  final int startMs;

  /// Optional end time in milliseconds (if provided in JSON).
  final int? endMs;

  HymnLine({
    required this.startMs,
    this.endMs,
    this.image,
    this.text,
  });

  factory HymnLine.fromJson(Map<String, dynamic> j) => HymnLine(
        image: j['image'] as String?,
        text: j['text'] as String?,
        startMs: ((j['startMs'] ?? j['s']) as num).toInt(),
        endMs: (j['endMs'] ?? j['e']) == null
            ? null
            : ((j['endMs'] ?? j['e']) as num).toInt(),
      );
}

class HymnData {
  final String id;
  final String title;

  /// Main font family for hymn text (optional).
  final String? fontFamily;

  /// Optional author.
  final String? author;

  /// Audio asset path (supports "audioAsset" or "audio").
  final String audioAsset;

  /// Optional PDF asset path (supports "pdfAsset" or "pdf").
  final String? pdfAsset;

  final List<HymnLine> lines;

  HymnData({
    required this.id,
    required this.title,
    required this.audioAsset,
    required this.lines,
    this.pdfAsset,
    this.fontFamily,
    this.author,
  });

  factory HymnData.fromJson(Map<String, dynamic> j) => HymnData(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? 'Hymn') as String,
        fontFamily: j['fontFamily'] as String?,
        author: j['author'] as String?,
        audioAsset: (j['audioAsset'] ?? j['audio']) as String,
        pdfAsset: (j['pdfAsset'] ?? j['pdf']) as String?,
        lines: (j['lines'] as List)
            .map((x) => HymnLine.fromJson(x as Map<String, dynamic>))
            .toList(),
      );
}