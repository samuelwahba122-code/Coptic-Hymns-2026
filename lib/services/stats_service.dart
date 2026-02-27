import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserStats {
  final int xp;
  final int totalListeningMs;
  final int hymnsCompleted;

  const UserStats({
    required this.xp,
    required this.totalListeningMs,
    required this.hymnsCompleted,
  });

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'totalListeningMs': totalListeningMs,
        'hymnsCompleted': hymnsCompleted,
      };

  factory UserStats.fromJson(Map<String, dynamic> j) => UserStats(
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        totalListeningMs: (j['totalListeningMs'] as num?)?.toInt() ?? 0,
        hymnsCompleted: (j['hymnsCompleted'] as num?)?.toInt() ?? 0,
      );
}

class StatsService {
  StatsService._();
  static final instance = StatsService._();

  static const _kKey = 'user_stats_v1';
  SharedPreferences? _sp;

  Future<SharedPreferences> _prefs() async {
    _sp ??= await SharedPreferences.getInstance();
    return _sp!;
  }

  Future<UserStats> getStats() async {
    final sp = await _prefs();
    final raw = sp.getString(_kKey);
    if (raw == null || raw.isEmpty) {
      return const UserStats(xp: 0, totalListeningMs: 0, hymnsCompleted: 0);
    }
    return UserStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _save(UserStats s) async {
    final sp = await _prefs();
    await sp.setString(_kKey, jsonEncode(s.toJson()));
  }

  Future<void> addXp(int amount) async {
    if (amount <= 0) return;
    final s = await getStats();
    await _save(UserStats(
      xp: s.xp + amount,
      totalListeningMs: s.totalListeningMs,
      hymnsCompleted: s.hymnsCompleted,
    ));
  }

  Future<void> addListeningMs(int ms) async {
    if (ms <= 0) return;
    final s = await getStats();
    await _save(UserStats(
      xp: s.xp,
      totalListeningMs: s.totalListeningMs + ms,
      hymnsCompleted: s.hymnsCompleted,
    ));
  }

  Future<void> incrementHymnsCompleted() async {
    final s = await getStats();
    await _save(UserStats(
      xp: s.xp,
      totalListeningMs: s.totalListeningMs,
      hymnsCompleted: s.hymnsCompleted + 1,
    ));
  }
}