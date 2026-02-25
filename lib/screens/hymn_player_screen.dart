import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/shared_audio_player.dart';
import '../models/hymn_models.dart';
import '../widgets/audio_controls.dart';
import '../widgets/hazzat.dart';
import '../widgets/text_layer.dart';
import 'pdf_hymn_screen.dart';

enum HymnPage { hymn, settings }
enum ViewMode { single, list }

class HymnPlayerScreen extends StatefulWidget {
  const HymnPlayerScreen({
    super.key,
    required this.hymnJsonAsset,
    required this.hymnTitle,
    this.author,
  });

  final String hymnJsonAsset;
  final String hymnTitle;
  final String? author;

  @override
  State<HymnPlayerScreen> createState() => _HymnPlayerScreenState();
}

class _HymnPlayerScreenState extends State<HymnPlayerScreen> {
  final ScrollController _scrollController = ScrollController();
  final _shared = SharedAudioPlayer.instance;

  bool _immersive = false;
  bool _audioPlaying = false;

  HymnData? _data;
  String? _error;

  int _activeIndex = 0;

  // Settings
  bool _followAudio = true;
  ViewMode _viewMode = ViewMode.single;

  // which page is visible (Hymn / Settings)
  HymnPage _page = HymnPage.hymn;

  // List mode: exact scroll-to-selected
  final Map<int, GlobalKey> _rowKeys = {};

  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _scrollController.dispose();

    // restore bars when leaving screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _enterImmersive() async {
    if (_immersive) return;
    _immersive = true;
    if (mounted) setState(() {});
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _exitImmersive() async {
    if (!_immersive) return;
    _immersive = false;
    if (mounted) setState(() {});
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _init() async {
    try {
      final raw = await rootBundle.loadString(widget.hymnJsonAsset);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final data = HymnData.fromJson(map);

      await _shared.loadAssetIfNeeded(data.audioAsset);

      _playingSub?.cancel();
      _playingSub = _shared.player.playingStream.listen((playing) {
        _audioPlaying = playing;
        if (playing) {
          _enterImmersive();
        } else {
          _exitImmersive();
        }
      });

      _positionSub?.cancel();
      _positionSub = _shared.player.positionStream.listen((pos) async {
        if (!_followAudio) return;

        final ms = pos.inMilliseconds;
        final idx = _findActiveLine(data.lines, ms);

        if (idx != _activeIndex && mounted) {
          setState(() => _activeIndex = idx);
          await _ensureLineVisible(idx);
        }
      });

      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  int _findActiveLine(List<HymnLine> lines, int posMs) {
    if (lines.isEmpty) return 0;

    for (int i = 0; i < lines.length; i++) {
      final start = lines[i].startMs;

      final end = lines[i].endMs ??
          ((i + 1 < lines.length) ? lines[i + 1].startMs : 1 << 30);

      if (posMs >= start && posMs < end) return i;
    }
    return 0;
  }

  Future<void> _ensureLineVisible(int idx) async {
    if (_viewMode != ViewMode.list) return;

    final key = _rowKeys[idx];
    final ctx = key?.currentContext;
    if (ctx == null) return;

    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.25,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goTo(int index, {bool play = false}) async {
    final data = _data!;
    final clamped = index.clamp(0, data.lines.length - 1);

    setState(() => _activeIndex = clamped);

    await _shared.player.seek(
      Duration(milliseconds: data.lines[clamped].startMs),
    );
    if (play) await _shared.player.play();

    await _ensureLineVisible(clamped);
  }

  Future<void> _playFromCurrentLine() async {
    await _goTo(_activeIndex, play: true);
  }

  Widget _buildLineImage(String assetPath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 3,
        panEnabled: true,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Image.asset(assetPath),
        ),
      ),
    );
  }

Widget _buildLineText(HymnData data, HymnLine line, {required bool active}) {
  final segs = line.segments;
  if (segs.isEmpty) return const SizedBox.shrink();

  final baseColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.92);
  final activeColor = const Color(0xFFC9A24A);
  final color = active ? activeColor : baseColor;

  TextStyle styleFor(String type) {
    return TextStyle(
      fontFamily: type == 'franco' ? 'Roboto' : data.fontFamily,
      fontSize: 22,
      height: 1.8,
      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
      color: color,
    );
  }

  // If you want explicit spacing between segments, keep the " " addition below.
  return Hazzat(
    child: RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          for (final seg in segs)
            TextSpan(
              text: seg.value, // or "${seg.value} "
              style: styleFor(seg.type),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildSingleMode(HymnData data) {
    final line = data.lines[_activeIndex];
    final hasImage = (line.image ?? '').trim().isNotEmpty;

    return Column(
      children: [
        AudioControls(
          player: _shared.player,
          trailing: IconButton(
            tooltip: "Play from current line",
            icon: const Icon(Icons.play_circle_fill),
            onPressed: _playFromCurrentLine,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: hasImage
                ? _buildLineImage(line.image!)
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildLineText(data, line, active: true),
                    ),
                  ),
          ),
        ),
        if (hasImage)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _buildLineText(data, line, active: true),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _activeIndex > 0 ? () => _goTo(_activeIndex - 1) : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text("Prev"),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Line ${_activeIndex + 1} / ${data.lines.length}",
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _activeIndex < data.lines.length - 1
                    ? () => _goTo(_activeIndex + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text("Next"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListMode(HymnData data) {
    return Column(
      children: [
        AudioControls(
          player: _shared.player,
          trailing: IconButton(
            tooltip: "Play from current line",
            icon: const Icon(Icons.play_circle_fill),
            onPressed: _playFromCurrentLine,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: data.lines.length,
            itemBuilder: (context, i) {
              final line = data.lines[i];
              final active = (i == _activeIndex);

              final key = _rowKeys.putIfAbsent(i, () => GlobalKey());

              final hasImage = (line.image ?? '').trim().isNotEmpty;
              final hasText = ((line.text ?? '').trim().isNotEmpty) ||
                  ((line.franco ?? '').trim().isNotEmpty);

              return Container(
                key: key,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: InkWell(
                  onTap: () => _goTo(i, play: true),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFC9A24A).withOpacity(0.14)
                          : Theme.of(context).colorScheme.surface.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active
                            ? const Color(0xFFC9A24A).withOpacity(0.55)
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFC9A24A).withOpacity(0.18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.14),
                            ),
                          ),
                          child: Text(
                            "${i + 1}",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (hasText) _buildLineText(data, line, active: active),
                              if (hasText && hasImage) const SizedBox(height: 8),
                              if (hasImage)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(line.image!, fit: BoxFit.contain),
                                ),
                              if (!hasText && !hasImage)
                                Text(
                                  "Line ${i + 1}",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettings() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SwitchListTile(
          title: const Text("Follow audio"),
          subtitle: const Text("Automatically switch the active line while audio plays."),
          value: _followAudio,
          onChanged: (v) => setState(() => _followAudio = v),
        ),
        const Divider(),
        ListTile(
          title: const Text("Display mode"),
          subtitle: const Text("Choose list view or line-by-line view."),
          trailing: SegmentedButton<ViewMode>(
            segments: const [
              ButtonSegment(value: ViewMode.single, label: Text("Single")),
              ButtonSegment(value: ViewMode.list, label: Text("List")),
            ],
            selected: {_viewMode},
            onSelectionChanged: (s) async {
              final next = s.first;
              setState(() => _viewMode = next);
              await _ensureLineVisible(_activeIndex);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.hymnTitle)),
        body: Center(child: Text(_error!)),
      );
    }

    final data = _data;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasPdf = (data.pdfAsset ?? '').trim().isNotEmpty;

    return WillPopScope(
      onWillPop: () async {
        if (_page == HymnPage.settings) {
          setState(() => _page = HymnPage.hymn);
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: _immersive
            ? null
            : AppBar(
                title: Text(_page == HymnPage.hymn ? data.title : "Settings"),
                actions: [
                  IconButton(
                    tooltip: hasPdf ? "Open PDF" : "No PDF available",
                    icon: const Icon(Icons.picture_as_pdf),
                    onPressed: hasPdf
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PdfHymnScreen(
                                  title: data.title,
                                  pdfAssetPath: data.pdfAsset!,
                                  sharedPlayer: _shared.player,
                                ),
                              ),
                            )
                        : null,
                  ),
                  PopupMenuButton<HymnPage>(
                    tooltip: "Menu",
                    initialValue: _page,
                    onSelected: (p) => setState(() => _page = p),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: HymnPage.hymn,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.music_note),
                          title: Text("Hymn"),
                        ),
                      ),
                      PopupMenuItem(
                        value: HymnPage.settings,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.settings),
                          title: Text("Settings"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_immersive) {
              _exitImmersive();
            } else if (_audioPlaying) {
              _enterImmersive();
            }
          },
          child: IndexedStack(
            index: _page == HymnPage.hymn ? 0 : 1,
            children: [
              _viewMode == ViewMode.single ? _buildSingleMode(data) : _buildListMode(data),
              _buildSettings(),
            ],
          ),
        ),
      ),
    );
  }
}