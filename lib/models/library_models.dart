class HymnRef {
  final String id;
  final String title;
  final String jsonAsset;
  final String? author;

  HymnRef({
    required this.id,
    required this.title,
    required this.jsonAsset,
    this.author,
  });

  factory HymnRef.fromJson(Map<String, dynamic> j) => HymnRef(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        jsonAsset: j['jsonAsset'] as String,
        author: j['author'] as String?, // ✅ hymn-level author
      );
}

class HymnGroup {
  final String id;
  final String title;
  final List<HymnRef> hymns;

  HymnGroup({
    required this.id,
    required this.title,
    required this.hymns,
  });

  factory HymnGroup.fromJson(Map<String, dynamic> j) => HymnGroup(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        hymns: (j['hymns'] as List)
            .map((x) => HymnRef.fromJson(x as Map<String, dynamic>))
            .toList(),
      );
}

class LibraryData {
  final List<HymnGroup> groups;

  LibraryData({required this.groups});

  factory LibraryData.fromJson(Map<String, dynamic> j) => LibraryData(
        groups: (j['groups'] as List)
            .map((x) => HymnGroup.fromJson(x as Map<String, dynamic>))
            .toList(),
      );
}
