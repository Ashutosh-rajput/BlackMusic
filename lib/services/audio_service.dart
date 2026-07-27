import 'package:audio_session/audio_session.dart';
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

  Future<void> _setupAudioPlayer() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      _logger.w('Failed to configure AudioSession: $e');
    }

    _audioPlayer.playbackEventStream.listen((event) {
      _logger.d('Playback event: ${event.processingState}');
    }, onError: (Object e, StackTrace st) {
      _logger.e('Audio player playback error: $e');
    });
  }

  Future<void> play(String path) async {
    try {
      AudioSource source;
      if (path.startsWith('http://') || path.startsWith('https://')) {
        source = AudioSource.uri(
          Uri.parse(path),
          headers: const {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        );
      } else if (path.startsWith('asset://') || path.startsWith('assets/')) {
        final assetPath = path.replaceFirst('asset://', '');
        source = AudioSource.uri(Uri.parse('asset:///$assetPath'));
      } else {
        final cleanPath = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
        source = AudioSource.uri(Uri.file(cleanPath));
      }

      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.play();
    } on PlayerInterruptedException {
      _logger.i('Audio loading interrupted by user/new playback request.');
    } catch (e) {
      if (e.toString().contains('Loading interrupted')) {
        _logger.i('Audio loading interrupted: $e');
        return;
      }
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
