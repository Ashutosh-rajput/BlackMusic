import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:pixel_player/data/database/app_database.dart' hide Song;
import 'package:pixel_player/data/models/lyrics_model.dart';
import 'package:pixel_player/data/models/song_model.dart';

class LyricSearchResultItem {
  final String id;
  final String trackName;
  final String artistName;
  final String albumName;
  final double duration;
  final String timingType; // 'word', 'line', 'plain', 'instrumental'
  final String source; // 'binimum', 'lrclib'
  final String? lyricsUrl; // TTML URL
  final String? syncedLyrics; // LRC format
  final String? plainLyrics;
  final bool instrumental;

  LyricSearchResultItem({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    required this.timingType,
    required this.source,
    this.lyricsUrl,
    this.syncedLyrics,
    this.plainLyrics,
    this.instrumental = false,
  });

  bool get isWordSynced => timingType == 'word';
  bool get isLineSynced => timingType == 'line' || (syncedLyrics != null && syncedLyrics!.isNotEmpty);
  bool get hasPlain => plainLyrics != null && plainLyrics!.trim().isNotEmpty;

  factory LyricSearchResultItem.fromBinimum(Map<String, dynamic> json) {
    final timing = json['timing_type']?.toString().toLowerCase() ?? 'line';
    return LyricSearchResultItem(
      id: json['id']?.toString() ?? '',
      trackName: json['track_name']?.toString() ?? '',
      artistName: json['artist_name']?.toString() ?? '',
      albumName: json['album_name']?.toString() ?? '',
      duration: (json['duration'] is num) ? (json['duration'] as num).toDouble() : 0.0,
      timingType: timing,
      source: 'binimum',
      lyricsUrl: json['lyricsUrl']?.toString(),
    );
  }

  factory LyricSearchResultItem.fromLrcLib(Map<String, dynamic> json) {
    final synced = json['syncedLyrics']?.toString();
    final isInst = json['instrumental'] == true;
    final timing = isInst ? 'instrumental' : (synced != null && synced.trim().isNotEmpty ? 'line' : 'plain');

    return LyricSearchResultItem(
      id: json['id']?.toString() ?? '',
      trackName: json['trackName']?.toString() ?? json['name']?.toString() ?? '',
      artistName: json['artistName']?.toString() ?? '',
      albumName: json['albumName']?.toString() ?? '',
      duration: (json['duration'] is num) ? (json['duration'] as num).toDouble() : 0.0,
      timingType: timing,
      source: 'lrclib',
      syncedLyrics: synced,
      plainLyrics: json['plainLyrics']?.toString(),
      instrumental: isInst,
    );
  }
}

class LyricsService {
  final AppDatabase _database;
  final Dio _dio;
  final Logger _logger = Logger();

  static const String _binimumApiBase = 'https://lyrics-api.binimum.org';
  static const String _lrclibBaseUrl = 'https://lrclib.net';
  static const String _userAgent =
      'PixelPlayer/1.0 (https://github.com/Ashutosh-rajput/flutter_application_1; contact: support@pixelplayer.app)';

  LyricsService(this._database, [Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: {
                  'User-Agent': _userAgent,
                  'Accept': 'application/json',
                },
              ),
            );

  /// Cleans track title / artist names for optimal search matches.
  static String cleanQuery(String text) {
    return text
        .replaceAll(RegExp(r'\([^)]*(official|video|audio|remix|feat|ft|from|version|lyrics)[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[[^\]]*(official|video|audio|remix|feat|ft|from|version|lyrics)[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'(feat|ft)\.?\s+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[_|\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Looks for a companion .lrc file in the same directory as the local audio file.
  File? _getLocalLrcFile(String audioFilePath) {
    try {
      final dotIndex = audioFilePath.lastIndexOf('.');
      if (dotIndex != -1) {
        final lrcPath = '${audioFilePath.substring(0, dotIndex)}.lrc';
        return File(lrcPath);
      }
    } catch (_) {}
    return null;
  }

  /// Gets lyrics for a given song with multi-tier priority:
  /// 1. Local companion .lrc file (for local storage tracks)
  /// 2. SQLite cached lyrics
  /// 3. lyrics.binimum.org API (Word-timed TTML top priority!)
  /// 4. LRCLIB API fallback (Line-timed synced LRC)
  Future<LyricsData> getLyrics(Song song, {bool forceRefresh = false}) async {
    // 1. Check local companion .lrc file if it's a local file
    if (!song.filePath.startsWith('http')) {
      final lrcFile = _getLocalLrcFile(song.filePath);
      if (lrcFile != null && await lrcFile.exists()) {
        try {
          final content = await lrcFile.readAsString();
          if (content.trim().isNotEmpty) {
            _logger.i('Loaded lyrics from companion .lrc file for ${song.title}');
            return LrcParser.parse(content, source: 'local_lrc');
          }
        } catch (e) {
          _logger.w('Error reading local .lrc file: $e');
        }
      }
    }

    // 2. Check SQLite database cache
    if (!forceRefresh) {
      try {
        final cached = await _database.getLyricsBySongId(song.id);
        if (cached != null) {
          if (cached.format == 'instrumental') {
            return LyricsData.instrumental(source: 'cache');
          }
          if (cached.format.startsWith('ttml')) {
            return TtmlParser.parse(cached.content, source: 'cache');
          }
          return LrcParser.parse(cached.content, source: 'cache');
        }
      } catch (e) {
        _logger.w('Error loading lyrics from cache: $e');
      }
    }

    // 3. PRIORITY 1: Search binimum.org for Word-timed / Line-timed TTML
    try {
      final binimumLyrics = await _fetchFromBinimum(song);
      if (binimumLyrics != null && binimumLyrics.isSynced) {
        await _saveLyricsToCache(song.id, binimumLyrics);
        return binimumLyrics;
      }
    } catch (e) {
      _logger.w('Binimum lyrics lookup failed: $e');
    }

    // 4. PRIORITY 2: Search LRCLIB fallback
    try {
      final lrcLibLyrics = await _fetchFromLrcLib(song);
      if (lrcLibLyrics != null) {
        await _saveLyricsToCache(song.id, lrcLibLyrics);
        return lrcLibLyrics;
      }
    } catch (e) {
      _logger.w('LRCLIB fallback failed: $e');
    }

    return LyricsData.empty();
  }

  Future<void> _saveLyricsToCache(int songId, LyricsData lyrics) async {
    String format = lyrics.format ?? 'plain';
    String content = lyrics.rawContent;

    if (lyrics.isInstrumental) {
      format = 'instrumental';
      content = '';
    } else if (content.isEmpty) {
      if (lyrics.isSynced) {
        format = 'lrc';
        content = lyrics.lines.map((l) => l.toString()).join('\n');
      } else {
        format = 'plain';
        content = lyrics.plainLyrics ?? '';
      }
    }

    await _database.saveLyrics(
      songId: songId,
      content: content,
      format: format,
    );
  }

  /// Queries lyrics.binimum.org for TTML lyrics, searching ONLY by song name.
  Future<LyricsData?> _fetchFromBinimum(Song song) async {
    final cleanTitle = cleanQuery(song.title);
    final songTitle = cleanTitle.isNotEmpty ? cleanTitle : song.title;
    final durSeconds = song.duration.inSeconds;

    List<LyricSearchResultItem> candidates = [];

    // Attempt 1: Query by song name only
    try {
      final response = await _dio.get(
        _binimumApiBase,
        queryParameters: {'q': songTitle},
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final list = response.data['results'];
        if (list is List && list.isNotEmpty) {
          candidates.addAll(list.map((item) => LyricSearchResultItem.fromBinimum(item as Map<String, dynamic>)));
        }
      }
    } catch (_) {}

    // Attempt 2: Direct track name param fallback
    if (candidates.isEmpty) {
      try {
        final response = await _dio.get(
          _binimumApiBase,
          queryParameters: {'track': songTitle},
          options: Options(headers: {'Accept': 'application/json'}),
        );

        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          final list = response.data['results'];
          if (list is List && list.isNotEmpty) {
            candidates.addAll(list.map((item) => LyricSearchResultItem.fromBinimum(item as Map<String, dynamic>)));
          }
        }
      } catch (_) {}
    }

    if (candidates.isEmpty) return null;

    // Filter to items that actually have a lyricsUrl
    final withUrl = candidates.where((c) => c.lyricsUrl != null && c.lyricsUrl!.isNotEmpty).toList();
    if (withUrl.isEmpty) return null;

    // PRIORITIZE:
    // 1. timing_type == 'word'
    // 2. Duration proximity
    withUrl.sort((a, b) {
      if (a.isWordSynced && !b.isWordSynced) return -1;
      if (!a.isWordSynced && b.isWordSynced) return 1;

      if (durSeconds > 0) {
        final diffA = (a.duration - durSeconds).abs();
        final diffB = (b.duration - durSeconds).abs();
        return diffA.compareTo(diffB);
      }
      return 0;
    });

    // Try fetching the top matching candidates
    for (final candidate in withUrl.take(2)) {
      try {
        final ttmlRes = await _dio.get<String>(
          candidate.lyricsUrl!,
          options: Options(
            headers: {'Accept': 'application/ttml+xml, text/xml'},
            responseType: ResponseType.plain,
          ),
        );

        if (ttmlRes.statusCode == 200 && ttmlRes.data != null && ttmlRes.data!.isNotEmpty) {
          final parsed = TtmlParser.parse(ttmlRes.data!, source: 'binimum');
          if (parsed.isSynced) {
            _logger.i('Found binimum lyrics for ${song.title} (wordSynced: ${parsed.isWordSynced})');
            return parsed;
          }
        }
      } catch (e) {
        _logger.w('Failed to fetch TTML from ${candidate.lyricsUrl}: $e');
      }
    }

    return null;
  }

  /// LRCLIB signature and search lookup fallback, searching ONLY by song name
  Future<LyricsData?> _fetchFromLrcLib(Song song) async {
    final cleanTitle = cleanQuery(song.title);
    final songTitle = cleanTitle.isNotEmpty ? cleanTitle : song.title;
    final durSeconds = song.duration.inSeconds;

    // Attempt 1: Search by song title only
    try {
      final response = await _dio.get(
        '$_lrclibBaseUrl/api/search',
        queryParameters: {'q': songTitle},
      );
      if (response.statusCode == 200 && response.data is List && (response.data as List).isNotEmpty) {
        final results = (response.data as List)
            .map((item) => LyricSearchResultItem.fromLrcLib(item as Map<String, dynamic>))
            .toList();
        final best = _findBestLrcMatch(results, durSeconds);
        if (best != null) {
          return _lrcResultToLyricsData(best);
        }
      }
    } catch (_) {}

    // Attempt 2: Search by track_name parameter only
    try {
      final response = await _dio.get(
        '$_lrclibBaseUrl/api/search',
        queryParameters: {'track_name': songTitle},
      );
      if (response.statusCode == 200 && response.data is List && (response.data as List).isNotEmpty) {
        final results = (response.data as List)
            .map((item) => LyricSearchResultItem.fromLrcLib(item as Map<String, dynamic>))
            .toList();
        final best = _findBestLrcMatch(results, durSeconds);
        if (best != null) {
          return _lrcResultToLyricsData(best);
        }
      }
    } catch (_) {}

    return null;
  }

  LyricSearchResultItem? _findBestLrcMatch(List<LyricSearchResultItem> results, int targetDurSec) {
    if (results.isEmpty) return null;

    final synced = results.where((r) => r.isLineSynced).toList();
    if (synced.isNotEmpty) {
      if (targetDurSec > 0) {
        synced.sort((a, b) =>
            (a.duration - targetDurSec).abs().compareTo((b.duration - targetDurSec).abs()));
      }
      return synced.first;
    }

    final plain = results.where((r) => r.hasPlain || r.instrumental).toList();
    if (plain.isNotEmpty) {
      if (targetDurSec > 0) {
        plain.sort((a, b) =>
            (a.duration - targetDurSec).abs().compareTo((b.duration - targetDurSec).abs()));
      }
      return plain.first;
    }

    return results.first;
  }

  LyricsData _lrcResultToLyricsData(LyricSearchResultItem result) {
    if (result.instrumental) {
      return LyricsData.instrumental(source: 'lrclib');
    }
    if (result.syncedLyrics != null && result.syncedLyrics!.isNotEmpty) {
      return LrcParser.parse(result.syncedLyrics!, source: 'lrclib');
    }
    if (result.hasPlain) {
      return LrcParser.parse(result.plainLyrics!, source: 'lrclib');
    }
    return LyricsData.empty();
  }

  /// Searches both binimum.org (word/line TTML) and LRCLIB (LRC)
  Future<List<LyricSearchResultItem>> searchLyrics(String query) async {
    final List<LyricSearchResultItem> combined = [];

    // Search binimum.org
    try {
      final binRes = await _dio.get(
        _binimumApiBase,
        queryParameters: {'q': query},
      );
      if (binRes.statusCode == 200 && binRes.data is Map<String, dynamic>) {
        final list = binRes.data['results'];
        if (list is List) {
          combined.addAll(
            list.map((item) => LyricSearchResultItem.fromBinimum(item as Map<String, dynamic>)),
          );
        }
      }
    } catch (e) {
      _logger.w('Search binimum error: $e');
    }

    // Search LRCLIB
    try {
      final lrcRes = await _dio.get(
        '$_lrclibBaseUrl/api/search',
        queryParameters: {'q': query},
      );
      if (lrcRes.statusCode == 200 && lrcRes.data is List) {
        combined.addAll(
          (lrcRes.data as List).map((item) => LyricSearchResultItem.fromLrcLib(item as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      _logger.w('Search LRCLIB error: $e');
    }

    // Sort word-timed to top, then line-synced
    combined.sort((a, b) {
      if (a.isWordSynced && !b.isWordSynced) return -1;
      if (!a.isWordSynced && b.isWordSynced) return 1;
      if (a.isLineSynced && !b.isLineSynced) return -1;
      if (!a.isLineSynced && b.isLineSynced) return 1;
      return 0;
    });

    return combined;
  }

  /// Fetches and saves lyrics from a selected search result
  Future<LyricsData> saveSearchResult(int songId, LyricSearchResultItem item) async {
    if (item.source == 'binimum' && item.lyricsUrl != null) {
      try {
        final ttmlRes = await _dio.get<String>(
          item.lyricsUrl!,
          options: Options(
            headers: {'Accept': 'application/ttml+xml, text/xml'},
            responseType: ResponseType.plain,
          ),
        );
        if (ttmlRes.statusCode == 200 && ttmlRes.data != null) {
          final parsed = TtmlParser.parse(ttmlRes.data!, source: 'binimum');
          await _saveLyricsToCache(songId, parsed);
          return parsed;
        }
      } catch (e) {
        _logger.e('Failed to load TTML from search result: $e');
      }
    }

    // Otherwise LRCLIB or plain
    String format = 'plain';
    String content = '';
    if (item.instrumental) {
      format = 'instrumental';
    } else if (item.syncedLyrics != null && item.syncedLyrics!.isNotEmpty) {
      format = 'lrc';
      content = item.syncedLyrics!;
    } else if (item.plainLyrics != null && item.plainLyrics!.isNotEmpty) {
      format = 'plain';
      content = item.plainLyrics!;
    }

    await _database.saveLyrics(
      songId: songId,
      content: content,
      format: format,
    );

    if (item.instrumental) {
      return LyricsData.instrumental(source: item.source);
    }
    return LrcParser.parse(content, source: item.source);
  }

  /// Manually save lyrics for a song (from user input or custom LRC)
  Future<LyricsData> saveLyricsForSong(int songId, {String? lrcText, String? plainText, bool isInstrumental = false}) async {
    String format = 'plain';
    String content = '';

    if (isInstrumental) {
      format = 'instrumental';
    } else if (lrcText != null && lrcText.trim().isNotEmpty) {
      if (lrcText.contains('<tt') || lrcText.contains('<timedtext')) {
        format = 'ttml_line';
      } else {
        format = 'lrc';
      }
      content = lrcText;
    } else if (plainText != null && plainText.trim().isNotEmpty) {
      format = 'plain';
      content = plainText;
    }

    await _database.saveLyrics(
      songId: songId,
      content: content,
      format: format,
    );

    if (isInstrumental) {
      return LyricsData.instrumental(source: 'manual');
    }
    return LrcParser.parse(content, source: 'manual');
  }

  /// Delete cached lyrics for a song
  Future<void> deleteCachedLyrics(int songId) async {
    await _database.deleteLyricsBySongId(songId);
  }
}
