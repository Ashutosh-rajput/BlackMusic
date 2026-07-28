import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class FileService {
  static final OnAudioQuery _audioQuery = OnAudioQuery();
  static const List<String> supportedFormats = [
    'mp3', 'flac', 'aac', 'ogg', 'wav', 'm4a', 'opus', 'alac'
  ];

  /// Scans audio files via Android MediaStore or background isolate folder scanning.
  Future<List<Song>> scanMusicLibrary({
    List<String>? specificPaths,
    bool recursive = true,
  }) async {
    // 1. Android MediaStore Query (Fast, Scoped-Storage compliant, Zero ANR)
    if (Platform.isAndroid && (specificPaths == null || specificPaths.isEmpty)) {
      try {
        final audioModels = await _audioQuery.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        if (audioModels.isNotEmpty) {
          final songs = <Song>[];
          for (final item in audioModels) {
            if (item.data.isEmpty) continue;
            final pathHash = item.data.hashCode ^ (item.data.length * 37);
            final durMs = item.duration ?? 0;
            final dateSec = item.dateAdded ?? 0;
            final dateModified = dateSec > 0
                ? DateTime.fromMillisecondsSinceEpoch(dateSec * 1000)
                : DateTime.now();

            songs.add(Song(
              id: pathHash.abs(),
              title: item.title.trim().isNotEmpty ? item.title : 'Unknown Track',
              artist: (item.artist != null && item.artist != '<unknown>')
                  ? item.artist!
                  : 'Unknown Artist',
              album: (item.album != null && item.album != '<unknown>')
                  ? item.album!
                  : 'Local Music',
              filePath: item.data,
              duration: Duration(milliseconds: durMs > 0 ? durMs : 180000),
              fileSize: item.size,
              dateModified: dateModified,
              genre: item.genre,
              albumArtist: item.artist,
            ));
          }
          if (songs.isNotEmpty) return songs;
        }
      } catch (e) {
        _logger.w('MediaStore query warning ($e), falling back to background folder scan.');
      }
    }

    // 2. Off-Isolate Folder Walking (Non-blocking background compute)
    final targetPaths = <String>[];
    if (specificPaths != null && specificPaths.isNotEmpty) {
      targetPaths.addAll(specificPaths);
    } else if (Platform.isAndroid) {
      targetPaths.addAll([
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Audio',
      ]);
    } else {
      targetPaths.add(Directory.current.path);
    }

    try {
      final rawSongs = await compute(_backgroundFolderScan, _ScanParams(targetPaths, supportedFormats));
      return rawSongs;
    } catch (e) {
      _logger.e('Background folder scan error: $e');
      return [];
    }
  }

  static List<Song> getSeedSongs() => const [];
}

class _ScanParams {
  final List<String> paths;
  final List<String> extensions;
  _ScanParams(this.paths, this.extensions);
}

List<Song> _backgroundFolderScan(_ScanParams params) {
  final songs = <Song>[];
  final visited = <String>{};

  for (final pathStr in params.paths) {
    final dir = Directory(pathStr);
    if (!dir.existsSync()) continue;
    _syncScanDir(dir, songs, visited, params.extensions);
  }

  return songs;
}

void _syncScanDir(Directory dir, List<Song> songs, Set<String> visited, List<String> extensions) {
  try {
    final dirName = dir.path.split(RegExp(r'[/\\]')).last;
    if (dirName.startsWith('.') ||
        dir.path.contains('/Android/data') ||
        dir.path.contains('/Android/obb') ||
        dir.path.contains('/.cache')) {
      return;
    }

    final entities = dir.listSync(followLinks: false);
    for (final entity in entities) {
      if (entity is File) {
        if (visited.contains(entity.path)) continue;
        visited.add(entity.path);

        final ext = entity.path.split('.').last.toLowerCase();
        if (!extensions.contains(ext)) continue;

        final fileName = entity.path.split(RegExp(r'[/\\]')).last;
        final titleWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

        String title = titleWithoutExt;
        String artist = 'Unknown Artist';
        if (titleWithoutExt.contains(' - ')) {
          final parts = titleWithoutExt.split(' - ');
          artist = parts[0].trim();
          title = parts.sublist(1).join(' - ').trim();
        }

        final pathHash = entity.path.hashCode ^ (entity.path.length * 37);
        final stat = entity.statSync();

        songs.add(Song(
          id: pathHash.abs(),
          title: title,
          artist: artist,
          album: 'Local Music',
          filePath: entity.path,
          duration: const Duration(minutes: 3),
          fileSize: stat.size,
          dateModified: stat.modified,
          genre: 'Audio Track',
          albumArtist: artist,
        ));
      } else if (entity is Directory) {
        _syncScanDir(entity, songs, visited, extensions);
      }
    }
  } catch (_) {}
}
