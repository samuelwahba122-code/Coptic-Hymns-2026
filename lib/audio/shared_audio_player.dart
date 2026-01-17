import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class SharedAudioPlayer {
  SharedAudioPlayer._();
  static final SharedAudioPlayer instance = SharedAudioPlayer._();

  final AudioPlayer player = AudioPlayer();
  bool _sessionConfigured = false;
  String? _loadedAsset;

  Future<void> ensureSession() async {
    if (_sessionConfigured) return;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _sessionConfigured = true;
  }

  Future<void> loadAssetIfNeeded(String assetPath) async {
    await ensureSession();
    if (_loadedAsset == assetPath) return;
    await player.setAudioSource(AudioSource.asset(assetPath));
    _loadedAsset = assetPath;
  }
}
