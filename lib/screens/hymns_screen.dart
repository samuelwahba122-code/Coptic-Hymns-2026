import 'package:flutter/material.dart';

import '../models/library_models.dart';
import '../services/progress_service.dart';
import 'hymn_player_screen.dart';

class HymnsScreen extends StatelessWidget {
  final HymnGroup group;

  const HymnsScreen({
    super.key,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.title),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: group.hymns.length,
        itemBuilder: (context, i) {
          final h = group.hymns[i];

          final author = h.author ?? '';
          final hasAuthor = author.trim().isNotEmpty;

          return FutureBuilder(
            future: ProgressService.instance.getProgress(h.id),
            builder: (context, snap) {
              final p = snap.data;
              final percent = p?.percent ?? 0.0;
              // show progress if we have any saved progress object (even if 0%)
              final showProgress = true;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  elevation: 0,
                  color: cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasAuthor)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ),
                        if (showProgress) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: showProgress && percent < 1
                        ? const Icon(Icons.play_arrow)
                        : const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HymnPlayerScreen(
                            hymnJsonAsset: h.jsonAsset,
                            hymnId: h.title,
                            author: h.author,
                            resumePositionMs: p?.lastPositionMs,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}