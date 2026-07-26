import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  late final AudioPlayer _audioPlayer;

  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal() {
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  AudioPlayer get player => _audioPlayer;

  void _setupAudioPlayer() {
    _audioPlayer.playbackEventStream.listen((event) {
      _logger.d('Playback event: ${event.processingState}');
    }, onError: (Object e, StackTrace st) {
      _logger.e('Audio player playback error: $e');
    });
  }

  Future<void> play(String path) async {
    try {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        await _audioPlayer.setUrl(path);
      } else if (path.startsWith('asset://') || path.startsWith('assets/')) {
        final assetPath = path.replaceFirst('asset://', '');
        await _audioPlayer.setAsset(assetPath);
      } else {
        await _audioPlayer.setFilePath(path);
      }
      await _audioPlayer.play();
    } catch (e) {
      _logger.e('Error playing audio source ($path): $e');
      rethrow;
    }
  }

  Future<void> pause() => _audioPlayer.pause();

  Future<void> resume() => _audioPlayer.play();

  Future<void> stop() => _audioPlayer.stop();

  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  Future<void> setVolume(double volume) => _audioPlayer.setVolume(volume.clamp(0.0, 1.0));

  Future<void> setSpeed(double speed) => _audioPlayer.setSpeed(speed.clamp(0.5, 2.0));

  Future<void> setPlaybackRate(double rate) => setSpeed(rate);

  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  void dispose() => _audioPlayer.dispose();
}
