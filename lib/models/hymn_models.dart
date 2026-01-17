class HymnLine {
  final String image;
  final int startMs;

  HymnLine({required this.image, required this.startMs});

  factory HymnLine.fromJson(Map<String, dynamic> j) => HymnLine(
        image: j['image'] as String,
        startMs: (j['startMs'] as num).toInt(),
      );
}

class HymnData {
  final String title;
  final String audioAsset;
  final String pdfAsset;
  final List<HymnLine> lines;
  final String? author;

  HymnData({
    required this.title,
    required this.audioAsset,
    required this.pdfAsset,
    required this.lines,
    this.author,
    
  });

  factory HymnData.fromJson(Map<String, dynamic> j) => HymnData(
        title: (j['title'] ?? 'Hymn') as String,
        audioAsset: j['audioAsset'] as String,
        pdfAsset: j['pdfAsset'] as String,
        author: j['author'] as String,
        lines: (j['lines'] as List)
            .map((x) => HymnLine.fromJson(x as Map<String, dynamic>))
            .toList(),
      );
}
