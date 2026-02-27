import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hymn_app/services/stats_service.dart';
import '../models/library_models.dart';
import 'hymns_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  LibraryData? _lib;
  String? _error;

  String _q = "";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString("assets/hymns/library.json");
      final data = LibraryData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (mounted) setState(() => _lib = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Groups")),
        body: Center(child: Text(_error!)),
      );
    }
    final lib = _lib;
    if (lib == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final groups = lib.groups.where((g) {
      if (_q.trim().isEmpty) return true;
      return g.title.toLowerCase().contains(_q.trim().toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hymns Groups"),
        actions: [
          FutureBuilder(
            future: StatsService.instance.getStats(),
            builder: (context, snap) {
              final xp = snap.data?.xp ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Chip(
                    label: Text("XP $xp"),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            // Search
            TextField(
              onChanged: (v) => setState(() => _q = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Search groups…",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Count
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "${groups.length} group${groups.length == 1 ? "" : "s"}",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, i) {
                  final g = groups[i];
                  final hymnsCount = g.hymns.length;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                          ),
                          child: Icon(
                            Icons.library_music,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          g.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text("$hymnsCount hymn${hymnsCount == 1 ? "" : "s"}"),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => HymnsScreen(group: g)),
                        ),
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
