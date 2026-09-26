import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixel_player/core/utils/jiosaavn_decoder.dart';
import 'package:pixel_player/data/models/jiosaavn_item.dart';
import 'package:pixel_player/data/models/song_model.dart';

/// Interaction metrics recorded implicitly for a single song.
class SongInteraction {
  final int songId;
  final String title;
  final String artist;
  final String? genre;
  int playCount;
  int completeCount;
  int skipCount; // Skipped < 15s
  bool isFavorite;
  DateTime lastInteraction;

  SongInteraction({
    required this.songId,
    required this.title,
    required this.artist,
    this.genre,
    this.playCount = 0,
    this.completeCount = 0,
    this.skipCount = 0,
    this.isFavorite = false,
    required this.lastInteraction,
  });

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'title': title,
        'artist': artist,
        'genre': genre,
        'playCount': playCount,
        'completeCount': completeCount,
        'skipCount': skipCount,
        'isFavorite': isFavorite == true,
        'lastInteraction': lastInteraction.toIso8601String(),
      };

  factory SongInteraction.fromJson(Map<String, dynamic> json) => SongInteraction(
        songId: (json['songId'] is int)
            ? json['songId'] as int
            : int.tryParse(json['songId']?.toString() ?? '0') ?? 0,
        title: json['title']?.toString() ?? '',
        artist: json['artist']?.toString() ?? '',
        genre: json['genre']?.toString(),
        playCount: (json['playCount'] is int)
            ? json['playCount'] as int
            : int.tryParse(json['playCount']?.toString() ?? '0') ?? 0,
        completeCount: (json['completeCount'] is int)
            ? json['completeCount'] as int
            : int.tryParse(json['completeCount']?.toString() ?? '0') ?? 0,
        skipCount: (json['skipCount'] is int)
            ? json['skipCount'] as int
            : int.tryParse(json['skipCount']?.toString() ?? '0') ?? 0,
        isFavorite: json['isFavorite'] == true,
        lastInteraction: DateTime.tryParse(json['lastInteraction']?.toString() ?? '') ?? DateTime.now(),
      );

  /// Computes dynamic score using Spotify-style implicit & explicit feedback weights
  /// and exponential time-decay (30-day half-life).
  double computeAffinityScore(DateTime now) {
    final daysSince = max(0, now.difference(lastInteraction).inHours) / 24.0;
    // 30-day half life decay: lambda = ln(2) / 30 ~= 0.0231
    final decay = exp(-0.0231 * daysSince);

    // Weight formula:
    // Explicit Favorite = +6.0, Complete play = +1.5, regular start = +0.5, skip = -2.0
    final favBonus = (isFavorite == true) ? 6.0 : 0.0;
    final rawScore = (completeCount * 1.5) + (playCount * 0.5) + favBonus - (skipCount * 2.0);
    return max(0.0, rawScore) * decay;
  }
}

/// PulseIQ On-Device Taste Profiler and Candidate Recommendation Engine.
class UserTasteService {
  static const String _storageFileName = 'pulseiq_taste_profile.json';
  static UserTasteService? _instance;
  static UserTasteService get instance => _instance ??= UserTasteService();

  final Map<int, SongInteraction> _interactions = {};
  final Map<String, double> _artistAffinities = {};
  Timer? _saveDebounceTimer;
  File? _storageFile;
  bool _isInitialized = false;

  // Active track playback tracking state
  int? _activeSongId;
  DateTime? _activeSongStartTime;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  bool _completionRecorded = false;

  UserTasteService() {
    _instance = this;
  }

  Future<File> _resolveStorageFile() async {
    if (_storageFile != null) return _storageFile!;
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory.systemTemp;
    }
    _storageFile = File('${baseDir.path}/$_storageFileName');
    return _storageFile!;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _resolveStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic> && decoded['interactions'] is List) {
            for (final item in decoded['interactions'] as List) {
              if (item is Map<String, dynamic>) {
                try {
                  final interaction = SongInteraction.fromJson(item);
                  _interactions[interaction.songId] = interaction;
                } catch (e) {
                  debugPrint('PulseIQ: Skipped corrupt item in taste profile: $e');
                }
              }
            }
          }
        }
      }
      _recalculateArtistAffinities();
      _isInitialized = true;
    } catch (e) {
      debugPrint('PulseIQ UserTasteService init error: $e');
    }
  }

  void _recalculateArtistAffinities() {
    _artistAffinities.clear();
    final now = DateTime.now();

    for (final inter in _interactions.values) {
      final cleanArtist = inter.artist.trim();
      if (cleanArtist.isEmpty || cleanArtist.toLowerCase() == 'unknown') continue;

      final songScore = inter.computeAffinityScore(now);
      _artistAffinities[cleanArtist] = (_artistAffinities[cleanArtist] ?? 0.0) + songScore;
    }
  }

  // --- Real-Time Implicit Signal Capture ---

  /// Called when a song begins playback.
  void onSongStarted(Song song) {
    final now = DateTime.now();

    // If previous song was active, check if it was skipped prematurely
    if (_activeSongId != null && _activeSongStartTime != null && !_completionRecorded) {
      final elapsed = now.difference(_activeSongStartTime!);
      if (elapsed.inSeconds < 15 && _lastPosition.inSeconds < 15) {
        _recordSkipInternal(_activeSongId!);
      }
    }

    _activeSongId = song.id;
    _activeSongStartTime = now;
    _lastPosition = Duration.zero;
    _lastDuration = song.duration;
    _completionRecorded = false;

    // Record or update interaction
    var interaction = _interactions[song.id];
    if (interaction == null) {
      interaction = SongInteraction(
        songId: song.id,
        title: song.title,
        artist: song.artist,
        genre: song.genre,
        playCount: 1,
        lastInteraction: now,
      );
      _interactions[song.id] = interaction;
    } else {
      interaction.playCount++;
      interaction.lastInteraction = now;
    }

    _recalculateArtistAffinities();
    _scheduleSave();
    debugPrint('PulseIQ: Started playing "${song.title}" by "${song.artist}" (plays: ${interaction.playCount})');
  }

  /// Called on playback progress stream.
  void onPlaybackProgress(Song song, Duration position, Duration duration) {
    if (_activeSongId != song.id) {
      _activeSongId = song.id;
      _activeSongStartTime ??= DateTime.now();
      _completionRecorded = false;
    }
    _lastPosition = position;
    if (duration > Duration.zero) _lastDuration = duration;

    // Spotify rule: Listening past 80% or 3 minutes counts as an intentional complete play
    if (!_completionRecorded && _lastDuration > Duration.zero) {
      final ratio = position.inMilliseconds / _lastDuration.inMilliseconds;
      if (ratio >= 0.80 || position.inSeconds >= 180) {
        onSongCompleted(song);
      }
    }
  }

  /// Explicitly called when user taps "Next" or skips before song naturally completes.
  void onSongSkipped(Song song) {
    if (_completionRecorded) return; // Not a negative skip if already completed
    final now = DateTime.now();
    final elapsed = _activeSongStartTime != null ? now.difference(_activeSongStartTime!).inSeconds : _lastPosition.inSeconds;

    if (elapsed < 15 || _lastPosition.inSeconds < 15) {
      _recordSkipInternal(song.id);
    }
  }

  /// Called when audio reaches completion.
  void onSongCompleted(Song song) {
    if (_completionRecorded) return; // Prevent double counting
    _completionRecorded = true;

    final now = DateTime.now();
    var interaction = _interactions[song.id];
    if (interaction == null) {
      interaction = SongInteraction(
        songId: song.id,
        title: song.title,
        artist: song.artist,
        genre: song.genre,
        playCount: 1,
        completeCount: 1,
        lastInteraction: now,
      );
      _interactions[song.id] = interaction;
    } else {
      interaction.completeCount++;
      interaction.lastInteraction = now;
    }

    _recalculateArtistAffinities();
    _scheduleSave();
    debugPrint('PulseIQ: Recorded completion for "${song.title}" by "${song.artist}" (completed: ${interaction.completeCount} times)');
  }

  /// Explicitly records when a track is marked or unmarked as favorite.
  void onSongFavoriteToggled(Song song, bool isFav) {
    final now = DateTime.now();
    var interaction = _interactions[song.id];
    if (interaction == null) {
      interaction = SongInteraction(
        songId: song.id,
        title: song.title,
        artist: song.artist,
        genre: song.genre,
        isFavorite: isFav,
        lastInteraction: now,
      );
      _interactions[song.id] = interaction;
    } else {
      interaction.isFavorite = isFav;
      interaction.lastInteraction = now;
    }

    _recalculateArtistAffinities();
    _scheduleSave();
    debugPrint('PulseIQ: Recorded favorite=$isFav for "${song.title}" by "${song.artist}"');
  }

  void _recordSkipInternal(int songId) {
    final interaction = _interactions[songId];
    if (interaction != null) {
      interaction.skipCount++;
      interaction.lastInteraction = DateTime.now();
      _scheduleSave();
      debugPrint('PulseIQ: Recorded skip penalty for "${interaction.title}" (skips: ${interaction.skipCount})');
    }
  }

  // --- Taste Metrics & Recommendations ---

  /// Returns top artists sorted by dynamic affinity score.
  List<String> getTopArtists({int limit = 10}) {
    _recalculateArtistAffinities();
    final sorted = _artistAffinities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Scores a candidate song against the user's on-device taste profile.
  double scoreCandidate(JioSaavnItem candidate) {
    final now = DateTime.now();
    double score = 1.0; // Base score

    // 1. Artist affinity check
    final artist = candidate.subtitle.trim();
    if (artist.isNotEmpty) {
      for (final entry in _artistAffinities.entries) {
        if (artist.toLowerCase().contains(entry.key.toLowerCase())) {
          score += (entry.value * 2.0).clamp(0.0, 10.0);
          break;
        }
      }
    }

    // 2. Prior interaction history check (if user already heard it)
    final candidateId = int.tryParse(candidate.id) ?? (candidate.id.isNotEmpty ? candidate.id : candidate.token).hashCode.abs();
    final interaction = _interactions[candidateId];
    if (interaction != null) {
      final affinity = interaction.computeAffinityScore(now);
      score += affinity;
      if (interaction.isFavorite == true) {
        score += 8.0; // Major boost for favorited track
      }
      if (interaction.skipCount > interaction.completeCount) {
        score -= (interaction.skipCount * 3.0); // Significant penalty for skipped tracks
      }
    }

    return max(0.1, score);
  }

  /// Maximal Marginal Relevance (MMR) Diversity Filter:
  /// Prevents echo chambers by limiting max tracks per artist.
  List<JioSaavnItem> rankAndFilterWithMMR(
    List<JioSaavnItem> candidates, {
    int maxPerArtist = 2,
    int maxResults = 25,
  }) {
    final scored = candidates.map((item) => (item, scoreCandidate(item))).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    final result = <JioSaavnItem>[];
    final artistCount = <String, int>{};

    for (final pair in scored) {
      if (result.length >= maxResults) break;
      final item = pair.$1;
      final primaryArtist = item.subtitle.split(',').first.trim().toLowerCase();

      final count = artistCount[primaryArtist] ?? 0;
      if (count < maxPerArtist || primaryArtist.isEmpty) {
        result.add(item);
        artistCount[primaryArtist] = count + 1;
      }
    }

    return result;
  }

  /// Strategy 2: Multi-Seed Harvesting
  /// Fetches suggestions for up to 3 distinct seed songs in parallel.
  /// Tracks co-occurrence: songs appearing across multiple seed lists get a high-confidence boost!
  Future<Map<JioSaavnItem, int>> fetchMultiSeedCandidates(
    List<Song> seedSongs, {
    int perSeedLimit = 15,
  }) async {
    final Map<String, (JioSaavnItem, int)> occurrences = {};

    final futures = seedSongs.take(3).map((song) async {
      try {
        final query = '${song.title} ${song.artist}'.trim();
        final searchResults = await JioSaavnDecoder.searchSongs(query);
        String? seedId;
        if (searchResults.isNotEmpty) {
          final match = searchResults.firstWhere((s) => s.id.isNotEmpty, orElse: () => searchResults.first);
          seedId = match.id.isNotEmpty ? match.id : match.token;
        }

        if (seedId != null && seedId.isNotEmpty) {
          final suggestions = await JioSaavnDecoder.fetchSongSuggestions(seedId, limit: perSeedLimit);
          return suggestions;
        }
      } catch (e) {
        debugPrint('PulseIQ MultiSeed error for ${song.title}: $e');
      }
      return <JioSaavnItem>[];
    });

    final results = await Future.wait(futures);
    for (final list in results) {
      for (final item in list) {
        if (!item.isSong || item.title.trim().isEmpty) continue;
        final key = (item.id.isNotEmpty ? item.id : item.title.toLowerCase().trim());
        if (occurrences.containsKey(key)) {
          final existing = occurrences[key]!;
          occurrences[key] = (existing.$1, existing.$2 + 1);
        } else {
          occurrences[key] = (item, 1);
        }
      }
    }

    final Map<JioSaavnItem, int> candidateMap = {};
    for (final entry in occurrences.values) {
      candidateMap[entry.$1] = entry.$2;
    }
    return candidateMap;
  }

  /// Strategy 3: Artist Collaboration & Composer Radar
  /// Extracts primary artists, featured artists, and composers from the user's top songs.
  /// Queries their top catalogs for tracks the user hasn't heard yet.
  Future<List<JioSaavnItem>> fetchComposerAndCollaborationRadar(
    List<Song> topSongs, {
    int perCreatorLimit = 10,
    int maxCreators = 3,
  }) async {
    final List<JioSaavnItem> radarCandidates = [];
    final Set<String> targetCreators = {};

    for (final song in topSongs) {
      if (targetCreators.length >= maxCreators) break;
      final candidates = [
        ...song.artist.split(RegExp(r'[,&/]')),
        if (song.albumArtist != null) ...song.albumArtist!.split(RegExp(r'[,&/]')),
      ].map((s) => s.trim()).where((s) => s.isNotEmpty && s.toLowerCase() != 'unknown');

      for (final name in candidates) {
        if (targetCreators.length < maxCreators && !targetCreators.contains(name.toLowerCase())) {
          targetCreators.add(name);
        }
      }
    }

    final futures = targetCreators.map((creator) async {
      try {
        final results = await JioSaavnDecoder.searchSongs(creator);
        return results.where((item) => item.isSong && item.title.isNotEmpty).take(perCreatorLimit).toList();
      } catch (_) {
        return <JioSaavnItem>[];
      }
    });

    final results = await Future.wait(futures);
    for (final list in results) {
      radarCandidates.addAll(list);
    }

    return radarCandidates;
  }

  /// High-level PulseIQ personalized recommendation pipeline combining:
  /// 1. Multi-Seed Harvesting (cross-seed co-occurrence boosts)
  /// 2. Artist Collaboration & Composer Radar
  /// 3. MMR Diversity Filter & Skip-penalty Scoring
  Future<List<JioSaavnItem>> getPersonalizedSuggestions({
    required List<Song> topPlayed,
    required List<Song> streamHistory,
    List<Song> favorites = const [],
    String lang = 'hindi',
    int limit = 15,
  }) async {
    try {
      // 1. Determine top 3 seed tracks: Favorites are given highest priority!
      final List<Song> seeds = [];
      final seenSeedTitles = <String>{};

      for (final song in [...favorites, ...topPlayed, ...streamHistory]) {
        if (seeds.length >= 3) break;
        final norm = song.title.toLowerCase().trim();
        if (!seenSeedTitles.contains(norm) && norm.isNotEmpty) {
          seenSeedTitles.add(norm);
          seeds.add(song);
        }
      }

      // If user has zero listening history, fallback to language search seeds
      if (seeds.isEmpty) {
        try {
          final popular = await JioSaavnDecoder.searchSongs(lang);
          seeds.addAll(popular.take(3).map((item) => item.toSong()));
        } catch (_) {}
      }

      if (seeds.isEmpty) return [];

      // 2. Run Strategy 2 (Multi-Seed Harvesting) and Strategy 3 (Composer Radar) concurrently!
      final multiSeedFuture = fetchMultiSeedCandidates(seeds, perSeedLimit: 15);
      final composerRadarFuture = fetchComposerAndCollaborationRadar(seeds, perCreatorLimit: 8, maxCreators: 3);

      final combined = await Future.wait([multiSeedFuture, composerRadarFuture]);
      final multiSeedMap = combined[0] as Map<JioSaavnItem, int>;
      final composerCandidates = combined[1] as List<JioSaavnItem>;

      // 3. Assemble pool with co-occurrence weights
      final Map<String, (JioSaavnItem, int)> pool = {};

      for (final entry in multiSeedMap.entries) {
        final key = entry.key.id.isNotEmpty ? entry.key.id : entry.key.title.toLowerCase().trim();
        pool[key] = (entry.key, entry.value);
      }

      for (final item in composerCandidates) {
        final key = item.id.isNotEmpty ? item.id : item.title.toLowerCase().trim();
        if (pool.containsKey(key)) {
          final existing = pool[key]!;
          pool[key] = (existing.$1, existing.$2 + 1);
        } else {
          pool[key] = (item, 1);
        }
      }

      // 4. Filter out songs the user has already played recently
      final playedTitles = {
        ...topPlayed.map((s) => s.title.toLowerCase().trim()),
        ...streamHistory.map((s) => s.title.toLowerCase().trim())
      };
      final candidateList = pool.values
          .where((p) => !playedTitles.contains(p.$1.title.toLowerCase().trim()))
          .toList();

      final finalCandidates = candidateList.isNotEmpty ? candidateList : pool.values.toList();

      // 5. Score candidates with PulseIQ and Co-occurrence boost
      final scoredCandidates = finalCandidates.map((pair) {
        final item = pair.$1;
        final coOccurrences = pair.$2;
        double score = scoreCandidate(item);
        if (coOccurrences > 1) {
          score += (coOccurrences - 1) * 4.0; // High confidence multi-seed overlap boost
        }
        return (item, score);
      }).toList();

      debugPrint('PulseIQ: Generating suggestions from ${seeds.length} seeds: ${seeds.map((s) => s.title).toList()}');

      // 6. Apply MMR Diversity filter (max 2 songs per artist)
      scoredCandidates.sort((a, b) => b.$2.compareTo(a.$2));

      final result = <JioSaavnItem>[];
      final artistCount = <String, int>{};

      for (final pair in scoredCandidates) {
        if (result.length >= limit) break;
        final item = pair.$1;
        final primaryArtist = item.subtitle.split(',').first.trim().toLowerCase();

        final count = artistCount[primaryArtist] ?? 0;
        if (count < 2 || primaryArtist.isEmpty) {
          result.add(item);
          artistCount[primaryArtist] = count + 1;
        }
      }

      debugPrint('PulseIQ: Harvested ${pool.length} pool tracks -> curated ${result.length} suggestions.');
      return result;
    } catch (e) {
      debugPrint('PulseIQ getPersonalizedSuggestions error: $e');
      return [];
    }
  }

  /// Generates next Smart Autoplay recommendations given the current song.
  Future<List<Song>> getSmartAutoplayRecommendations(Song currentSong, {int limit = 10}) async {
    try {
      List<JioSaavnItem> candidates = [];

      // 1. Seed retrieval: Get authentic JioSaavn ID
      final searchQuery = '${currentSong.title} ${currentSong.artist}'.trim();
      final searchResults = await JioSaavnDecoder.searchSongs(searchQuery);

      String? seedId;
      if (searchResults.isNotEmpty) {
        final match = searchResults.firstWhere((s) => s.id.isNotEmpty, orElse: () => searchResults.first);
        seedId = match.id.isNotEmpty ? match.id : match.token;
      }

      if (seedId != null && seedId.isNotEmpty) {
        candidates = await JioSaavnDecoder.fetchSongSuggestions(seedId, limit: 30);
      }

      // 2. Fallback to top taste artist if suggestions are sparse
      if (candidates.length < 5) {
        final topArtists = getTopArtists(limit: 3);
        final fallbackArtist = topArtists.isNotEmpty ? topArtists.first : currentSong.artist;
        if (fallbackArtist.isNotEmpty && fallbackArtist != 'Unknown') {
          final artistResults = await JioSaavnDecoder.searchSongs(fallbackArtist);
          candidates.addAll(artistResults.where((i) => i.isSong));
        }
      }

      // 3. Filter out current song & duplicates
      final currentTitle = currentSong.title.trim().toLowerCase();
      final filteredCandidates = candidates.where((item) {
        return item.isSong &&
            item.title.trim().isNotEmpty &&
            item.title.trim().toLowerCase() != currentTitle;
      }).toList();

      // 4. Re-rank with PulseIQ taste scoring & MMR diversity filter
      final reranked = rankAndFilterWithMMR(filteredCandidates, maxPerArtist: 2, maxResults: limit);

      // 5. Convert to playable Song models
      final result = reranked
          .map((item) => item.toSong())
          .where((s) => s.filePath.trim().isNotEmpty)
          .toList();
      debugPrint('PulseIQ: Smart Autoplay queued ${result.length} tracks for "${currentSong.title}"');
      return result;
    } catch (e) {
      debugPrint('PulseIQ: Error generating Smart Autoplay: $e');
      return [];
    }
  }

  void _scheduleSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(seconds: 3), _saveToFile);
  }

  Future<void> _saveToFile() async {
    try {
      final file = await _resolveStorageFile();
      final interactionList = _interactions.values.map((i) => i.toJson()).toList();
      final data = {
        'interactions': interactionList,
      };
      await file.writeAsString(jsonEncode(data));
      _recalculateArtistAffinities();
    } catch (e, st) {
      debugPrint('PulseIQ: Failed to save taste profile: $e\n$st');
    }
  }
}
