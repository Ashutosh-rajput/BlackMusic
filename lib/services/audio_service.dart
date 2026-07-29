import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  AudioPlayer? _audioPlayer;

  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal();

  AudioPlayer get player {
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      _setupAudioPlayer();
    }
    return _audioPlayer!;
  }

  void _setupAudioPlayer() {
    _audioPlayer?.playbackEventStream.listen((event) {
      _logger.d('Playback event: ${event.processingState}');
    }, onError: (Object e, StackTrace st) {
      _logger.e('Audio player playback error: $e');
    });
  }

  Uri? _parseArtUri(String? artPath) {
    if (artPath == null || artPath.trim().isEmpty) return null;
    final trimmed = artPath.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.tryParse(trimmed);
    }
    final cleanPath = trimmed.startsWith('file://') ? Uri.parse(trimmed).toFilePath() : trimmed;
    return Uri.file(cleanPath);
  }

  AudioSource _buildAudioSource(Song song) {
    MediaItem? mediaItem;
    try {
      mediaItem = MediaItem(
        id: song.id.toString(),
        album: song.album,
        title: song.title,
        artist: song.artist,
        artUri: _parseArtUri(song.albumArt),
      );
    } catch (e) {
      _logger.w('Error building MediaItem tag: $e');
    }

    final path = song.filePath;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return AudioSource.uri(
        Uri.parse(path),
        tag: mediaItem,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );
    } else if (path.startsWith('asset://') || path.startsWith('assets/')) {
      final assetPath = path.replaceFirst('asset://', '');
      return AudioSource.uri(
        Uri.parse('asset:///$assetPath'),
        tag: mediaItem,
      );
    } else {
      final cleanPath = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
      return AudioSource.uri(
        Uri.file(cleanPath),
        tag: mediaItem,
      );
    }
  }

  Future<void> prepare(Song song) async {
    try {
      final source = _buildAudioSource(song);
      await player.setAudioSource(source);
    } on PlayerInterruptedException {
      _logger.i('Audio loading interrupted by new request.');
    } catch (e) {
      if (e.toString().contains('Loading interrupted')) return;
      _logger.e('Error preparing audio source (${song.filePath}): $e');
    }
  }

  Future<void> play(String path, {Song? songInfo}) async {
    try {
      AudioSource source;
      if (songInfo != null) {
        source = _buildAudioSource(songInfo);
      } else {
        if (path.startsWith('http://') || path.startsWith('https://')) {
          source = AudioSource.uri(Uri.parse(path));
        } else {
          final cleanPath = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
          source = AudioSource.uri(Uri.file(cleanPath));
        }
      }
      await player.setAudioSource(source);
      await player.play();
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

  Future<void> playQueue(List<Song> queue, {required int initialIndex}) async {
    if (queue.isEmpty) return;
    try {
      final audioSources = queue.map(_buildAudioSource).toList();
      final safeIndex = initialIndex.clamp(0, queue.length - 1);
      await player.setAudioSources(audioSources, initialIndex: safeIndex);
      await player.play();
    } on PlayerInterruptedException {
      _logger.i('Queue playback interrupted by new request.');
    } catch (e) {
      if (e.toString().contains('Loading interrupted')) return;
      _logger.e('Error playing audio queue: $e');
      rethrow;
    }
  }

  Future<void> pause() => player.pause();

  Future<void> resume() => player.play();

  Future<void> stop() => player.stop();

  Future<void> seek(Duration position) => player.seek(position);

  Future<void> setVolume(double volume) => player.setVolume(volume.clamp(0.0, 1.0));

  Future<void> setSpeed(double speed) => player.setSpeed(speed.clamp(0.5, 2.0));

  Future<void> setPlaybackRate(double rate) => setSpeed(rate);

  Future<void> seekToNext() async {
    if (player.hasNext) {
      await player.seekToNext();
    }
  }

  Future<void> seekToPrevious() async {
    if (player.hasPrevious) {
      await player.seekToPrevious();
    }
  }

  Future<void> seekToIndex(int index) async {
    if (index >= 0 && index < player.sequence.length) {
      await player.seek(Duration.zero, index: index);
    }
  }

  Stream<int?> get currentIndexStream => player.currentIndexStream;

  Stream<Duration> get positionStream => player.positionStream;

  Stream<PlayerState> get playerStateStream => player.playerStateStream;

  Stream<Duration?> get durationStream => player.durationStream;

  void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}
