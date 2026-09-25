import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/services/settings_service.dart';

class StreamCacheEntry {
  final int songId;
  final String title;
  final String artist;
  final String? album;
  final String? albumArt;
  final String filePath;
  final String originalUrl;
  final DateTime cachedAt;
  DateTime lastAccessedAt;
  final int sizeBytes;

  StreamCacheEntry({
    required this.songId,
    required this.title,
    required this.artist,
    this.album,
    this.albumArt,
    required this.filePath,
    required this.originalUrl,
    required this.cachedAt,
    required this.lastAccessedAt,
    required this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'title': title,
        'artist': artist,
        'album': album,
        'albumArt': albumArt,
        'filePath': filePath,
        'originalUrl': originalUrl,
        'cachedAt': cachedAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
        'sizeBytes': sizeBytes,
      };

  factory StreamCacheEntry.fromJson(Map<String, dynamic> json) => StreamCacheEntry(
        songId: json['songId'] as int,
        title: json['title'] as String? ?? 'Track',
        artist: json['artist'] as String? ?? 'Unknown',
        album: json['album'] as String?,
        albumArt: json['albumArt'] as String?,
        filePath: json['filePath'] as String,
        originalUrl: json['originalUrl'] as String? ?? '',
        cachedAt: DateTime.tryParse(json['cachedAt'] as String? ?? '') ?? DateTime.now(),
        lastAccessedAt: DateTime.tryParse(json['lastAccessedAt'] as String? ?? '') ?? DateTime.now(),
        sizeBytes: json['sizeBytes'] as int? ?? 0,
      );
}

/// Service that maintains a local audio cache of the last 50 streamed songs.
/// Provides offline/instant playback of streamed songs without re-downloading.
class StreamCacheService {
  static const int maxCacheEntries = 50;
  static const String cacheDirName = 'stream_cache';
  static const String indexFileName = 'stream_cache_index.json';

  static StreamCacheService? _instance;
  static StreamCacheService get instance => _instance ??= StreamCacheService();

  final Map<int, StreamCacheEntry> _entries = {};
  final Set<int> _downloadingIds = {};
  Directory? _cacheDir;
  bool _isInitialized = false;
  Timer? _saveDebounceTimer;

  StreamCacheService() {
    _instance = this;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      Directory baseDir;
      try {
        baseDir = await getApplicationCacheDirectory();
      } catch (_) {
        baseDir = Directory.systemTemp;
      }

      _cacheDir = Directory('${baseDir.path}/$cacheDirName');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }

      final indexFile = File('${_cacheDir!.path}/$indexFileName');
      if (await indexFile.exists()) {
        final content = await indexFile.readAsString();
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                try {
                  final entry = StreamCacheEntry.fromJson(item);
                  if (File(entry.filePath).existsSync()) {
                    _entries[entry.songId] = entry;
                  }
                } catch (_) {}
              }
            }
          }
        }
      }

      _pruneCacheIfNeeded();
      _isInitialized = true;
    } catch (e) {
      debugPrint('StreamCacheService init error: $e');
    }
  }

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      return _cacheDir!;
    }
    await init();
    return _cacheDir ?? Directory.systemTemp;
  }

  /// Checks if a song is cached locally and its file exists on disk.
  bool isSongCached(int songId) {
    final entry = _entries[songId];
    if (entry == null) return false;
    if (File(entry.filePath).existsSync()) {
      return true;
    } else {
      _entries.remove(songId);
      _scheduleSaveIndex();
      return false;
    }
  }

  /// Returns the local cached audio file path if available, and updates access timestamp.
  String? getCachedFilePath(int songId) {
    final entry = _entries[songId];
    if (entry != null) {
      final file = File(entry.filePath);
      if (file.existsSync()) {
        entry.lastAccessedAt = DateTime.now();
        _scheduleSaveIndex();
        return entry.filePath;
      } else {
        _entries.remove(songId);
        _scheduleSaveIndex();
      }
    }
    return null;
  }

  int get cachedCount => _entries.length;

  double get totalSizeMb {
    int total = 0;
    for (final e in _entries.values) {
      total += e.sizeBytes;
    }
    return total / (1024 * 1024);
  }

  List<StreamCacheEntry> get entries => _entries.values.toList();

  final List<_CacheQueueItem> _queue = [];
  bool _isProcessingQueue = false;

  /// Asynchronously caches a stream song to disk, maintaining the max 50 entries limit.
  /// Uses a sequential queue so at most one background download occurs at a time without network contention.
  Future<String?> cacheSong(Song song) async {
    final path = song.filePath.trim();
    if (!path.startsWith('http://') && !path.startsWith('https://')) {
      return null;
    }

    try {
      if (getIt.isRegistered<SettingsService>() && !getIt<SettingsService>().cacheStreamSongs) {
        return null;
      }
    } catch (_) {}

    if (isSongCached(song.id)) {
      return getCachedFilePath(song.id);
    }

    if (_downloadingIds.contains(song.id)) {
      return null;
    }

    if (_queue.any((item) => item.song.id == song.id)) {
      return null;
    }

    final completer = Completer<String?>();
    _queue.add(_CacheQueueItem(song, completer));
    _processQueue();
    return completer.future;
  }

  void _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    try {
      while (_queue.isNotEmpty) {
        final item = _queue.removeAt(0);
        try {
          final result = await _executeCacheSong(item.song);
          if (!item.completer.isCompleted) {
            item.completer.complete(result);
          }
        } catch (e) {
          if (!item.completer.isCompleted) {
            item.completer.complete(null);
          }
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<String?> _executeCacheSong(Song song) async {
    final path = song.filePath.trim();
    if (isSongCached(song.id)) {
      return getCachedFilePath(song.id);
    }

    if (_downloadingIds.contains(song.id)) {
      return null;
    }

    _downloadingIds.add(song.id);

    try {
      final dir = await _getCacheDir();
      final targetFilePath = '${dir.path}/${song.id}.m4a';
      final tempFilePath = '${dir.path}/${song.id}.m4a.part';

      final tempFile = File(tempFilePath);
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      final dio = Dio();
      try {
        await dio.download(
          path,
          tempFilePath,
          options: Options(
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
            receiveTimeout: const Duration(seconds: 45),
            sendTimeout: const Duration(seconds: 25),
          ),
        );
      } finally {
        dio.close();
      }

      if (await tempFile.exists() && await tempFile.length() > 0) {
        final targetFile = await tempFile.rename(targetFilePath);
        final size = await targetFile.length();

        final entry = StreamCacheEntry(
          songId: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          albumArt: song.albumArt,
          filePath: targetFilePath,
          originalUrl: path,
          cachedAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
          sizeBytes: size,
        );

        _entries[song.id] = entry;
        _pruneCacheIfNeeded();
        await _saveIndex();
        debugPrint('StreamCache: Cached "${song.title}" (${(size / (1024 * 1024)).toStringAsFixed(2)} MB)');
        return targetFilePath;
      }
    } catch (e) {
      debugPrint('StreamCache: Error caching song ${song.title}: $e');
    } finally {
      _downloadingIds.remove(song.id);
    }
    return null;
  }

  /// Prunes oldest cached stream songs when exceeding maxCacheEntries (50).
  void _pruneCacheIfNeeded() {
    if (_entries.length <= maxCacheEntries) return;

    final sorted = _entries.values.toList()
      ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));

    final countToEvict = _entries.length - maxCacheEntries;
    final toRemove = sorted.take(countToEvict).toList();

    for (final evict in toRemove) {
      _entries.remove(evict.songId);
      try {
        final f = File(evict.filePath);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (e) {
        debugPrint('StreamCache: Error deleting evicted file ${evict.filePath}: $e');
      }
    }
    debugPrint('StreamCache: Evicted $countToEvict songs to enforce $maxCacheEntries limit.');
  }

  void _scheduleSaveIndex() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(seconds: 2), () {
      _saveIndex();
    });
  }

  Future<void> _saveIndex() async {
    try {
      if (_cacheDir == null) return;
      final indexFile = File('${_cacheDir!.path}/$indexFileName');
      final jsonList = _entries.values.map((e) => e.toJson()).toList();
      await indexFile.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('StreamCache: Failed to write index: $e');
    }
  }

  /// Deletes all cached stream songs and clears index.
  Future<void> clearAllCache() async {
    try {
      for (final item in _queue) {
        if (!item.completer.isCompleted) {
          item.completer.complete(null);
        }
      }
      _queue.clear();
      _downloadingIds.clear();
      _entries.clear();
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await for (final entity in _cacheDir!.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
      debugPrint('StreamCache: All stream cache cleared.');
    } catch (e) {
      debugPrint('StreamCache: Error clearing cache: $e');
    }
  }
}

class _CacheQueueItem {
  final Song song;
  final Completer<String?> completer;
  _CacheQueueItem(this.song, this.completer);
}
