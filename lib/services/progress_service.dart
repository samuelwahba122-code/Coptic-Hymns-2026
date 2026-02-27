import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hymn_models.dart';
import 'stats_service.dart';

class HymnProgress {
  final String hymnId;
  final int lastPositionMs;
  final int completedLines;
  final int totalLines;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const HymnProgress({
    required this.hymnId,
    required this.lastPositionMs,
    required this.completedLines,
    required this.totalLines,
    required this.updatedAt,
    this.completedAt,
  });

  double get percent =>
      totalLines == 0 ? 0 : (completedLines / totalLines).clamp(0, 1);

  Map<String, dynamic> toJson() => {
        'hymnId': hymnId,
        'lastPositionMs': lastPositionMs,
        'completedLines': completedLines,
        'totalLines': totalLines,
        'updatedAt': updatedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory HymnProgress.fromJson(Map<String, dynamic> j) => HymnProgress(
        hymnId: j['hymnId'] as String,
        lastPositionMs: (j['lastPositionMs'] as num?)?.toInt() ?? 0,
        completedLines: (j['completedLines'] as num?)?.toInt() ?? 0,
        totalLines: (j['totalLines'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse(j['updatedAt'] ?? '') ?? DateTime.now(),
        completedAt: j['completedAt'] == null
            ? null
            : DateTime.tryParse(j['completedAt']),
      );
}

class ProgressService {
  ProgressService._();
  static final instance = ProgressService._();

  SharedPreferences? _sp;

  Future<SharedPreferences> _prefs() async {
    _sp ??= await SharedPreferences.getInstance();
    return _sp!;
  }

  String _key(String hymnId) => 'hymn_progress_v1_$hymnId';

  Future<HymnProgress?> getProgress(String hymnId) async {
    final sp = await _prefs();
    final raw = sp.getString(_key(hymnId));
    if (raw == null || raw.isEmpty) return null;
    return HymnProgress.fromJson(jsonDecode(raw));
  }

  Future<void> _save(HymnProgress p) async {
    final sp = await _prefs();
    await sp.setString(_key(p.hymnId), jsonEncode(p.toJson()));
  }

int _computeCompletedLines(int positionMs, List<HymnLine> lines) {
  int count = 0;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Prefer explicit end
    int end = line.e;

    // Fallback if end is invalid (0 or <= start): use next line start
    if (end <= line.s) {
      end = (i + 1 < lines.length) ? lines[i + 1].s : (1 << 30);
    }

    if (positionMs >= end) count++;
  }

  return count;
}

  Future<void> updateFromPosition({
    required String hymnId,
    required int positionMs,
    required List<HymnLine> lines,
  }) async {
    final prev = await getProgress(hymnId);

    final total = lines.length;
    final completed = _computeCompletedLines(positionMs, lines);

    final prevCompleted = prev?.completedLines ?? 0;
    final newlyCompleted = (completed - prevCompleted).clamp(0, total);

    // +1 XP per newly completed line
    if (newlyCompleted > 0) {
      await StatsService.instance.addXp(newlyCompleted);
    }

    final wasDone = (prev?.completedLines ?? 0) >= total && total > 0;
    final isDone = completed >= total && total > 0;

    final completedAt =
        (!wasDone && isDone) ? DateTime.now() : prev?.completedAt;

    await _save(
      HymnProgress(
        hymnId: hymnId,
        lastPositionMs: positionMs,
        completedLines: completed,
        totalLines: total,
        updatedAt: DateTime.now(),
        completedAt: completedAt,
      ),
    );

    // Completion bonus
    if (!wasDone && isDone) {
      await StatsService.instance.addXp(5);
      await StatsService.instance.incrementHymnsCompleted();
    }
  }
}