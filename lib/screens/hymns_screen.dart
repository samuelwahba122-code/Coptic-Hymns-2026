// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../models/library_models.dart';
import 'hymn_player_screen.dart';

class HymnsScreen extends StatefulWidget {
  const HymnsScreen({super.key, required this.group});

  final HymnGroup group;

  @override
  State<HymnsScreen> createState() => _HymnsScreenState();
}

class _HymnsScreenState extends State<HymnsScreen> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final group = widget.group;

    final q = _query.trim().toLowerCase();
    final hymns = group.hymns.where((h) {
      if (q.isEmpty) return true;
      final title = h.title.toLowerCase();
      final id = h.id.toLowerCase();
      final author = (h.author ?? "").toLowerCase();
      return title.contains(q) || id.contains(q) || author.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(group.title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Search hymns (title, author, id)…",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "${hymns.length} hymn${hymns.length == 1 ? "" : "s"}",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: hymns.length,
                itemBuilder: (context, index) {
                  final h = hymns[index];
                  final author = (h.author ?? "").trim();
                  final hasAuthor = author.isNotEmpty;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      elevation: 0,
                      color: cs.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        leading: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: cs.primary.withOpacity(0.10),
                          ),
                          child: Icon(Icons.music_note, color: cs.primary),
                        ),
                        title: Text(
                          h.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasAuthor)
                                Text(
                                  author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface.withOpacity(0.8),
                                  ),
                                ),
                              Text(
                                h.id,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HymnPlayerScreen(
                                hymnJsonAsset: h.jsonAsset,
                                hymnTitle: h.title,
                                author: h.author, // ✅ pass author
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
