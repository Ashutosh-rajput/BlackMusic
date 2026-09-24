import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:pixel_player/core/utils/hash_utils.dart';
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
    bool ignoreShortAudio = true,
    bool showHiddenFiles = false,
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
            final durMs = item.duration ?? 0;
            if (ignoreShortAudio && durMs > 0 && durMs < 30000) continue; // Filter short audio (<30s)

            final stableId = generateStableId(item.data);
            final dateSec = item.dateAdded ?? 0;
            final dateModified = dateSec > 0
                ? DateTime.fromMillisecondsSinceEpoch(dateSec * 1000)
                : DateTime.now();

            final audioId = item.id;
            final albumId = item.albumId;
            String artUriStr = 'mediastore://audio:$audioId';
            if (albumId != null) {
              artUriStr += '/album:$albumId';
            }

            songs.add(Song(
              id: stableId,
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
              albumArt: artUriStr,
              source: 'local',
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
      final rawSongs = await compute(
        _backgroundFolderScan,
        _ScanParams(
          paths: targetPaths,
          extensions: supportedFormats,
          ignoreShortAudio: ignoreShortAudio,
          showHiddenFiles: showHiddenFiles,
        ),
      );

      // Enrich folder-scanned songs with MediaStore artwork & metadata on Android
      if (Platform.isAndroid && rawSongs.isNotEmpty) {
        try {
          final mediaStoreSongs = await _audioQuery.querySongs();
          final pathMap = <String, SongModel>{};
          for (final m in mediaStoreSongs) {
            if (m.data.isNotEmpty) {
              final normalizedPath = m.data.toLowerCase().replaceAll(r'\', '/');
              pathMap[normalizedPath] = m;
            }
          }

          final enriched = rawSongs.map((song) {
            final key = song.filePath.toLowerCase().replaceAll(r'\', '/');
            final match = pathMap[key];
            if (match != null) {
              final audioId = match.id;
              final albumId = match.albumId;
              String artUriStr = 'mediastore://audio:$audioId';
              if (albumId != null) artUriStr += '/album:$albumId';

              final artist = (match.artist != null && match.artist != '<unknown>')
                  ? match.artist!
                  : song.artist;
              final album = (match.album != null && match.album != '<unknown>')
                  ? match.album!
                  : song.album;

              return song.copyWith(
                albumArt: artUriStr,
                artist: song.artist == 'Unknown Artist' ? artist : song.artist,
                album: song.album == 'Local Music' ? album : song.album,
              );
            }
            return song;
          }).toList();

          return enriched;
        } catch (e) {
          _logger.w('MediaStore enrichment warning ($e)');
        }
      }

      return rawSongs;
    } catch (e) {
      _logger.e('Background folder scan error: $e');
      return [];
    }
  }
}

class _ScanParams {
  final List<String> paths;
  final List<String> extensions;
  final bool ignoreShortAudio;
  final bool showHiddenFiles;

  _ScanParams({
    required this.paths,
    required this.extensions,
    this.ignoreShortAudio = true,
    this.showHiddenFiles = false,
  });
}

List<Song> _backgroundFolderScan(_ScanParams params) {
  final songs = <Song>[];
  final visitedFiles = <String>{};
  final visitedDirs = <String>{};

  for (final pathStr in params.paths) {
    final dir = Directory(pathStr);
    if (!dir.existsSync()) continue;
    _syncScanDir(dir, songs, visitedFiles, visitedDirs, params, depth: 0);
  }

  return songs;
}

void _syncScanDir(
  Directory dir,
  List<Song> songs,
  Set<String> visitedFiles,
  Set<String> visitedDirs,
  _ScanParams params, {
  required int depth,
}) {
  if (depth > 8) return; // Prevent stack overflow on deep folder structures

  try {
    final canonicalDir = dir.resolveSymbolicLinksSync();
    if (visitedDirs.contains(canonicalDir)) return;
    visitedDirs.add(canonicalDir);

    final dirName = dir.path.split(RegExp(r'[/\\]')).last;
    if (!params.showHiddenFiles && dirName.startsWith('.')) return;
    if (dir.path.contains('/Android/data') ||
        dir.path.contains('/Android/obb') ||
        dir.path.contains('/.cache')) {
      return;
    }

    final entities = dir.listSync(followLinks: false);
    for (final entity in entities) {
      if (entity is File) {
        if (visitedFiles.contains(entity.path)) continue;
        visitedFiles.add(entity.path);

        final ext = entity.path.split('.').last.toLowerCase();
        if (!params.extensions.contains(ext)) continue;

        final fileName = entity.path.split(RegExp(r'[/\\]')).last;
        if (!params.showHiddenFiles && fileName.startsWith('.')) continue;

        final stat = entity.statSync();
        if (params.ignoreShortAudio && stat.size < 100 * 1024) continue; // Skip files < 100 KB

        final titleWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
        String title = titleWithoutExt;
        String artist = 'Unknown Artist';
        if (titleWithoutExt.contains(' - ')) {
          final parts = titleWithoutExt.split(' - ');
          artist = parts[0].trim();
          title = parts.sublist(1).join(' - ').trim();
        }

        final stableId = generateStableId(entity.path);

        songs.add(Song(
          id: stableId,
          title: title,
          artist: artist,
          album: 'Local Music',
          filePath: entity.path,
          duration: const Duration(minutes: 3),
          fileSize: stat.size,
          dateModified: stat.modified,
          genre: 'Audio Track',
          albumArtist: artist,
          source: 'local',
        ));
      } else if (entity is Directory) {
        _syncScanDir(entity, songs, visitedFiles, visitedDirs, params, depth: depth + 1);
      }
    }
  } catch (_) {}
}
