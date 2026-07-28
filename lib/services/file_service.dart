import 'dart:io';
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
    Set<String> visitedPaths = {};

    List<Directory> targetDirs = [];
    if (specificPaths != null && specificPaths.isNotEmpty) {
      targetDirs = specificPaths.map((p) => Directory(p)).toList();
    } else {
      if (Platform.isAndroid) {
        final rootDir = Directory('/storage/emulated/0');
        if (rootDir.existsSync()) {
          targetDirs.add(rootDir);
        } else {
          final commonPaths = [
            '/storage/emulated/0/Music',
            '/storage/emulated/0/Download',
            '/storage/emulated/0/Audio',
            '/sdcard/Music',
            '/sdcard/Download',
          ];
          for (final path in commonPaths) {
            final dir = Directory(path);
            if (dir.existsSync()) targetDirs.add(dir);
          }
        }
      } else {
        targetDirs.add(Directory.current);
      }
    }

    for (var dir in targetDirs) {
      if (!await dir.exists()) continue;
      await _scanDirectory(dir, songs, visitedPaths, recursive: recursive);
    }

    return songs;
  }

  Future<void> _scanDirectory(
    Directory dir,
    List<Song> songs,
    Set<String> visitedPaths, {
    bool recursive = true,
  }) async {
    try {
      final dirName = dir.path.split(RegExp(r'[/\\]')).last;
      // Skip hidden directories and system app cache folders
      if (dirName.startsWith('.') ||
          dir.path.contains('/Android/data') ||
          dir.path.contains('/Android/obb') ||
          dir.path.contains('/.cache')) {
        return;
      }

      final entities = dir.listSync(followLinks: false);
      for (var entity in entities) {
        if (entity is File) {
          if (visitedPaths.contains(entity.path)) continue;
          visitedPaths.add(entity.path);
          final song = await _processAudioFile(entity);
          if (song != null) songs.add(song);
        } else if (entity is Directory && recursive) {
          await _scanDirectory(entity, songs, visitedPaths, recursive: recursive);
        }
      }
    } catch (e) {
      _logger.w('Skipping restricted directory ${dir.path}');
    }
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

      final pathHash = file.path.hashCode ^ (file.path.length * 37);

      return Song(
        id: pathHash.abs(),
        title: title,
        artist: artist,
        album: 'Local Music',
        filePath: file.path,
        duration: const Duration(minutes: 3),
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

  static List<Song> getSeedSongs() => const [];
}
