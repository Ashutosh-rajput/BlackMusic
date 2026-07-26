import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class FileService {
  static const List<String> supportedFormats = [
    'mp3', 'flac', 'aac', 'ogg', 'wav', 'm4a', 'opus', 'alac'
  ];

  /// Scans storage directories for audio files.
  Future<List<Song>> scanMusicLibrary({
    List<String>? specificPaths,
    bool recursive = true,
  }) async {
    List<Song> songs = [];

    Directory? musicDir;
    try {
      musicDir = await getExternalStorageDirectory();
    } catch (_) {}

    musicDir ??= Directory.current;

    final directories = specificPaths?.map((p) => Directory(p)).toList() ?? [musicDir];

    for (var dir in directories) {
      if (!await dir.exists()) continue;

      try {
        List<FileSystemEntity> entities = dir.listSync(recursive: recursive);
        for (var entity in entities) {
          if (entity is File) {
            final song = await _processAudioFile(entity);
            if (song != null) songs.add(song);
          }
        }
      } catch (e) {
        _logger.e('Error scanning directory ${dir.path}: $e');
      }
    }

    if (songs.isEmpty) {
      songs = getSeedSongs();
    }

    return songs;
  }

  Future<Song?> _processAudioFile(File file) async {
    try {
      final extension = file.path.split('.').last.toLowerCase();
      if (!supportedFormats.contains(extension)) return null;

      final fileName = file.path.split(RegExp(r'[/\\]')).last;
      final titleWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

      // Parse "Artist - Title" format if present
      String title = titleWithoutExt;
      String artist = 'Unknown Artist';
      if (titleWithoutExt.contains(' - ')) {
        final parts = titleWithoutExt.split(' - ');
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }

      return Song(
        id: file.path.hashCode,
        title: title,
        artist: artist,
        album: 'Local Music',
        filePath: file.path,
        duration: const Duration(minutes: 3, seconds: 30),
        fileSize: await file.length(),
        dateModified: await file.lastModified(),
        genre: 'Audio Track',
        albumArtist: artist,
      );
    } catch (e) {
      _logger.e('Error processing audio file ${file.path}: $e');
      return null;
    }
  }

  /// Default demo seed songs for instant out-of-the-box listening & testing
  static List<Song> getSeedSongs() {
    final now = DateTime.now();
    return [
      Song(
        id: 101,
        title: 'SoundHelix Song 1',
        artist: 'T. Schürger',
        album: 'Acoustic Dreams',
        filePath: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        duration: const Duration(minutes: 6, seconds: 12),
        dateModified: now,
        genre: 'Ambient',
        albumArt: 'https://picsum.photos/seed/soundhelix1/400/400',
      ),
      Song(
        id: 102,
        title: 'SoundHelix Song 2',
        artist: 'T. Schürger',
        album: 'Acoustic Dreams',
        filePath: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        duration: const Duration(minutes: 7, seconds: 5),
        dateModified: now,
        genre: 'Chillout',
        albumArt: 'https://picsum.photos/seed/soundhelix2/400/400',
      ),
      Song(
        id: 103,
        title: 'SoundHelix Song 3',
        artist: 'T. Schürger',
        album: 'Electronic Waves',
        filePath: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        duration: const Duration(minutes: 5, seconds: 44),
        dateModified: now,
        genre: 'Electronic',
        albumArt: 'https://picsum.photos/seed/soundhelix3/400/400',
      ),
      Song(
        id: 104,
        title: 'Midnight Serenade',
        artist: 'Pixel Studio',
        album: 'Night Vibe',
        filePath: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
        duration: const Duration(minutes: 5, seconds: 2),
        dateModified: now,
        genre: 'Lo-Fi',
        albumArt: 'https://picsum.photos/seed/pixelnight/400/400',
      ),
    ];
  }
}
