import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioControls extends StatelessWidget {
  const AudioControls({
    super.key,
    required this.player,
    this.trailing,
  });

  final AudioPlayer player;
  final Widget? trailing;

  String _fmt(Duration d) {
    final mm = d.inMinutes;
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isLandscape ? 6 : 12,
      ),
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (_, snap) {
              final st = snap.data;
              final playing = st?.playing ?? false;

              return IconButton(
                tooltip: playing ? "Pause" : "Play",
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: () => playing ? player.pause() : player.play(),
              );
            },
          ),
          IconButton(
            tooltip: "Back 10s",
            icon: const Icon(Icons.replay_10),
            onPressed: () async {
              final pos = player.position;
              final next = pos - const Duration(seconds: 10);
              await player.seek(next < Duration.zero ? Duration.zero : next);
            },
          ),
          IconButton(
            tooltip: "Forward 10s",
            icon: const Icon(Icons.forward_10),
            onPressed: () async {
              final pos = player.position;
              await player.seek(pos + const Duration(seconds: 10));
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (_, snap) {
                final pos = snap.data ?? Duration.zero;
                return Text(_fmt(pos));
              },
            ),
          ),
          if (trailing != null) trailing!,
          IconButton(
            tooltip: "Stop",
            icon: const Icon(Icons.stop),
            onPressed: () async {
              await player.pause();
              await player.seek(Duration.zero);
            },
          ),
        ],
      ),
    );
  }
}
