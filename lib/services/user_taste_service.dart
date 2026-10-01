import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vinyl/core/utils/jiosaavn_decoder.dart';
import 'package:vinyl/core/utils/song_dedupe.dart';
import 'package:vinyl/data/models/jiosaavn_item.dart';
import 'package:vinyl/data/models/song_model.dart';

/// Context for generating recommendations.
enum RecommendationContext {
  home,
  radio,
  autoplay,
}

/// One terminal outcome per playback session.
enum SessionOutcome {
  inProgress,
  completed,
  skipped,
  abandoned,
}

/// Represents an ongoing track listening session.
class PlaybackSession {
  final String trackKey;
  final Song song;
  final DateTime startTime;
  Duration lastPosition;
  Duration duration;
  SessionOutcome outcome;

  PlaybackSession({
    required this.trackKey,
    required this.song,
    required this.startTime,
    Duration? initialDuration,
  })  : lastPosition = Duration.zero,
        duration = initialDuration ?? song.duration,
        outcome = SessionOutcome.inProgress;

  bool get isTerminal => outcome != SessionOutcome.inProgress;
}

/// Interaction metrics recorded implicitly and explicitly for a track.
/// Uses separately decayed positive and negative score accumulators to prevent
/// new skips from reviving decayed completions (Solves Finding 1).
class SongInteraction {
  final String trackKey;
  final int songId;
  final String title;
  final String artist;
  final String? genre;
  int playCount;
  int completeCount;
  int skipCount;
  bool isFavorite;
  DateTime lastInteraction;
  int searchPlayCount;

  // Separate decayed signal accumulators (30-day half-life continuous decay)
  double positiveScore;
  double negativeScore;

  // Candidate metadata cached for high-priority recommendation reconstruction
  String? imageUrl;
  String? token;
  String? duration;
  String? language;

  SongInteraction({
    required this.trackKey,
    required this.songId,
    required this.title,
    required this.artist,
    this.genre,
    this.playCount = 0,
    this.completeCount = 0,
    this.skipCount = 0,
    this.isFavorite = false,
    required this.lastInteraction,
    this.searchPlayCount = 0,
    double? positiveScore,
    double? negativeScore,
    this.imageUrl,
    this.token,
    this.duration,
    this.language,
  })  : positiveScore = positiveScore ??
            ((completeCount * 1.5) + (playCount * 0.5) + (searchPlayCount * 5.0) + (isFavorite ? 3.0 : 0.0)),
        negativeScore = negativeScore ?? (skipCount * 2.0);

  // 30-day half life decay: lambda = ln(2) / 30 ~= 0.0231049
  static const double _lambda = 0.0231049;

  /// Key prefix of entries created by "add preferred artist".
  static const String artistPreferencePrefix = 'artist_pref:';

  /// True for a manually added preferred artist. These only feed artist
  /// affinity; they are not real songs and must never be recommended,
  /// used as a seed, or counted as a tracked song.
  bool get isArtistPreference => trackKey.startsWith(artistPreferencePrefix);

  void _decayAccumulators(DateTime now) {
    if (now.isBefore(lastInteraction)) return;
    final days = now.difference(lastInteraction).inSeconds / 86400.0;
    final factor = exp(-_lambda * days);
    positiveScore *= factor;
    negativeScore *= factor;
    lastInteraction = now;
  }

  void recordPlay(DateTime now) {
    _decayAccumulators(now);
    playCount++;
    positiveScore += 0.5;
  }

  void recordSearchPlay(DateTime now, {JioSaavnItem? item}) {
    _decayAccumulators(now);
    searchPlayCount++;
    positiveScore += 5.0; // High explicit user intent boost
    if (item != null) {
      if (item.imageUrl.isNotEmpty) imageUrl = item.imageUrl;
      if (item.token.isNotEmpty) token = item.token;
      if (item.duration != null && item.duration!.isNotEmpty) duration = item.duration;
      if (item.language != null && item.language!.isNotEmpty) language = item.language;
    }
  }

  void recordComplete(DateTime now) {
    _decayAccumulators(now);
    completeCount++;
    positiveScore += 1.5;
  }

  void recordSkip(DateTime now) {
    _decayAccumulators(now);
    skipCount++;
    negativeScore += 2.0;
  }

  void recordFavorite(DateTime now, bool fav) {
    _decayAccumulators(now);
    isFavorite = fav;
  }

  /// Reconstructs a JioSaavnItem candidate from interaction profile.
  JioSaavnItem toJioSaavnItem() {
    final idStr = trackKey.startsWith('jiosaavn:')
        ? trackKey.substring('jiosaavn:'.length)
        : songId.toString();
    return JioSaavnItem(
      type: 'song',
      id: idStr,
      token: (token != null && token!.isNotEmpty) ? token! : idStr,
      title: title,
      subtitle: artist,
      imageUrl: imageUrl ?? '',
      duration: duration,
      language: language,
    );
  }

  /// Computes dynamic score using separately decayed positive and negative signals.
  double computeAffinityScore(DateTime now) {
    final days = max(0.0, now.difference(lastInteraction).inSeconds / 86400.0);
    final factor = exp(-_lambda * days);
    final favBonus = isFavorite ? 3.0 : 0.0;
    final decayedPos = positiveScore * factor;
    final decayedNeg = negativeScore * factor;
    return max(0.0, (decayedPos + favBonus) - decayedNeg);
  }

  Map<String, dynamic> toJson() => {
        'trackKey': trackKey,
        'songId': songId,
        'title': title,
        'artist': artist,
        'genre': genre,
        'playCount': playCount,
        'completeCount': completeCount,
        'skipCount': skipCount,
        'isFavorite': isFavorite == true,
        'lastInteraction': lastInteraction.toIso8601String(),
        'searchPlayCount': searchPlayCount,
        'positiveScore': positiveScore,
        'negativeScore': negativeScore,
        'imageUrl': imageUrl,
        'token': token,
        'duration': duration,
        'language': language,
      };

  factory SongInteraction.fromJson(Map<String, dynamic> json) {
    final parsedSongId = (json['songId'] is int)
        ? json['songId'] as int
        : int.tryParse(json['songId']?.toString() ?? '0') ?? 0;
    final trackKey = json['trackKey']?.toString() ??
        (parsedSongId != 0 ? 'legacy:$parsedSongId' : 'unknown:${json['title']}');
    final playCount = (json['playCount'] is int)
        ? json['playCount'] as int
        : int.tryParse(json['playCount']?.toString() ?? '0') ?? 0;
    final completeCount = (json['completeCount'] is int)
        ? json['completeCount'] as int
        : int.tryParse(json['completeCount']?.toString() ?? '0') ?? 0;
    final skipCount = (json['skipCount'] is int)
        ? json['skipCount'] as int
        : int.tryParse(json['skipCount']?.toString() ?? '0') ?? 0;
    final isFavorite = json['isFavorite'] == true;
    final searchPlayCount = (json['searchPlayCount'] is int)
        ? json['searchPlayCount'] as int
        : int.tryParse(json['searchPlayCount']?.toString() ?? '0') ?? 0;
    final lastInteraction =
        DateTime.tryParse(json['lastInteraction']?.toString() ?? '') ?? DateTime.now();

    final positiveScore = (json['positiveScore'] is num)
        ? (json['positiveScore'] as num).toDouble()
        : ((completeCount * 1.5) + (playCount * 0.5) + (searchPlayCount * 5.0) + (isFavorite ? 3.0 : 0.0));
    final negativeScore = (json['negativeScore'] is num)
        ? (json['negativeScore'] as num).toDouble()
        : (skipCount * 2.0);

    return SongInteraction(
      trackKey: trackKey,
      songId: parsedSongId,
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      genre: json['genre']?.toString(),
      playCount: playCount,
      completeCount: completeCount,
      skipCount: skipCount,
      isFavorite: isFavorite,
      lastInteraction: lastInteraction,
      searchPlayCount: searchPlayCount,
      positiveScore: positiveScore,
      negativeScore: negativeScore,
      imageUrl: json['imageUrl']?.toString(),
      token: json['token']?.toString(),
      duration: json['duration']?.toString(),
      language: json['language']?.toString(),
    );
  }
}

typedef SearchSongsFn = Future<List<JioSaavnItem>> Function(String query);
typedef FetchSuggestionsFn = Future<List<JioSaavnItem>> Function(String id, {int limit});
typedef FetchNewReleasesFn = Future<List<JioSaavnItem>> Function({String lang});
typedef FetchSongArtistsFn = Future<List<({String id, String name})>> Function(String songId);
typedef FetchArtistSongsFn = Future<List<JioSaavnItem>> Function(String artistId, String songId, {String lang});

/// Kinds of tracks that should never follow unrelated music (e.g. an aarti or
/// a cartoon theme after a Bollywood song) unless the user listens to them.
enum ContentCategory { devotional, kids }

/// Detects devotional and kids content from a track's title / artist / album.
class ContentClassifier {
  static final RegExp _devotional = RegExp(
    r'\b(aarti|arti|aarati|bhajan|bhajans|chalisa|mantra|mantras|stotram|stotra|'
    r'kirtan|bhakti|amritwani|satsang|jaap|jap|vandana|stuti|aradhana|'
    r'om jai|jai jagdish|hanuman|ganpati aarti|shiv tandav|gayatri|sai baba|'
    r'krishna bhajan|mata ki|jai mata|jai ambe|shri ram jai|devotional)\b',
    caseSensitive: false,
  );

  static final RegExp _kids = RegExp(
    r'\b(rhymes?|nursery|lullaby|lori|cartoon|kids|children|baby shark|'
    r'motu patlu|chhota bheem|chota bheem|doraemon|shinchan|peppa|'
    r'bal geet|balgeet|poem for kids|theme song|kids song)\b',
    caseSensitive: false,
  );

  static ContentCategory? classify(String text) {
    if (text.trim().isEmpty) return null;
    if (_kids.hasMatch(text)) return ContentCategory.kids;
    if (_devotional.hasMatch(text)) return ContentCategory.devotional;
    return null;
  }

  static ContentCategory? ofItem(JioSaavnItem item) =>
      classify('${item.title} ${item.subtitle} ${item.music ?? ''}');

  static ContentCategory? ofSong(Song song) =>
      classify('${song.title} ${song.artist} ${song.album}');
}

/// PulseIQ On-Device Taste Profiler and Candidate Recommendation Engine.
class UserTasteService {
  static const String _storageFileName = 'pulseiq_taste_profile.json';
  static UserTasteService? _instance;
  static UserTasteService get instance => _instance ??= UserTasteService();

  final DateTime Function() _clock;
  final SearchSongsFn _searchSongs;
  final FetchSuggestionsFn _fetchSuggestions;
  final FetchNewReleasesFn _fetchNewReleases;
  final FetchSongArtistsFn _fetchSongArtists;
  final FetchArtistSongsFn _fetchArtistSongs;
  File? _storageFile;

  // Stored by canonical trackKey
  final Map<String, SongInteraction> _interactions = {};
  // Secondary lookup by integer songId for legacy migrations
  final Map<int, String> _songIdToTrackKey = {};
  final Map<String, double> _artistAffinities = {};
  final Set<String> _searchPlayedArtists = {};

  Timer? _saveDebounceTimer;
  bool _isInitialized = false;

  // Active playback session carrying single terminal outcome
  PlaybackSession? _activeSession;

  UserTasteService({
    DateTime Function()? clock,
    SearchSongsFn? searchSongs,
    FetchSuggestionsFn? fetchSuggestions,
    FetchNewReleasesFn? fetchNewReleases,
    FetchSongArtistsFn? fetchSongArtists,
    FetchArtistSongsFn? fetchArtistSongs,
    File? storageFile,
  })  : _clock = clock ?? DateTime.now,
        _searchSongs = searchSongs ?? JioSaavnDecoder.searchSongs,
        _fetchSuggestions = fetchSuggestions ?? JioSaavnDecoder.fetchSongSuggestions,
        // Like charts: when search is injected (tests), don't hit the network.
        _fetchSongArtists = fetchSongArtists ??
            (searchSongs == null ? JioSaavnDecoder.fetchSongArtists : (id) async => const []),
        _fetchArtistSongs = fetchArtistSongs ??
            (searchSongs == null
                ? JioSaavnDecoder.fetchArtistOtherSongs
                : (a, s, {String lang = ''}) async => const []),
        // When search is injected (tests) and no chart source is, don't hit
        // the network for charts; fall back to the injected search instead.
        _fetchNewReleases = fetchNewReleases ??
            (searchSongs == null ? JioSaavnDecoder.fetchNewReleases : ({String lang = ''}) async => const []),
        _storageFile = storageFile {
    _instance = this;
  }

  /// Splits and normalizes artist names into exact clean tokens.
  static List<String> parseArtistTokens(String artistsString) => parseArtistNames(artistsString);

  static String _canonicalKeyForSong(Song song) {
    return song.canonicalKey;
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
                  _interactions[interaction.trackKey] = interaction;
                  if (interaction.songId != 0) {
                    _songIdToTrackKey[interaction.songId] = interaction.trackKey;
                  }
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
    _searchPlayedArtists.clear();
    final now = _clock();

    for (final inter in _interactions.values) {
      final tokens = parseArtistTokens(inter.artist);
      if (tokens.isEmpty) continue;

      if (inter.searchPlayCount > 0) {
        for (final token in tokens) {
          _searchPlayedArtists.add(token);
        }
      }

      final songScore = inter.computeAffinityScore(now);
      if (songScore <= 0.0) continue;

      // Primary artist receives full score; collaborators receive half
      for (int i = 0; i < tokens.length; i++) {
        final token = tokens[i];
        final weight = i == 0 ? 1.0 : 0.5;
        _artistAffinities[token] = (_artistAffinities[token] ?? 0.0) + (songScore * weight);
      }
    }
  }

  SongInteraction? _getInteraction(String trackKey, [dynamic fallbackId]) {
    var interaction = _interactions[trackKey];
    if (interaction != null) return interaction;

    if (fallbackId != null) {
      final intId = (fallbackId is int) ? fallbackId : int.tryParse(fallbackId.toString());
      if (intId != null && _songIdToTrackKey.containsKey(intId)) {
        return _interactions[_songIdToTrackKey[intId]];
      }
    }
    return null;
  }

  SongInteraction _getOrCreateInteraction(Song song, {JioSaavnItem? item}) {
    final trackKey = _canonicalKeyForSong(song);
    var interaction = _getInteraction(trackKey, song.id);
    if (interaction == null) {
      interaction = SongInteraction(
        trackKey: trackKey,
        songId: song.id,
        title: song.title,
        artist: song.artist,
        genre: song.genre,
        lastInteraction: _clock(),
        imageUrl: item?.imageUrl ?? ((song.albumArt?.isNotEmpty ?? false) ? song.albumArt : null),
        token: item?.token,
        duration: item?.duration,
        language: item?.language,
      );
      _interactions[trackKey] = interaction;
      _songIdToTrackKey[song.id] = trackKey;
    } else {
      if (item != null) {
        if (item.imageUrl.isNotEmpty) interaction.imageUrl = item.imageUrl;
        if (item.token.isNotEmpty) interaction.token = item.token;
        if (item.duration != null && item.duration!.isNotEmpty) interaction.duration = item.duration;
        if (item.language != null && item.language!.isNotEmpty) interaction.language = item.language;
      }
    }
    return interaction;
  }

  /// Explicitly records high-intent playback initiated when user searches and selects a song.
  void recordSearchPlay(Song song, {JioSaavnItem? item}) {
    final now = _clock();
    final interaction = _getOrCreateInteraction(song, item: item);
    interaction.recordSearchPlay(now, item: item);

    _recalculateArtistAffinities();
    _scheduleSave();
    debugPrint('PulseIQ: High-intent search play recorded for "${song.title}" (searchCount: ${interaction.searchPlayCount})');
  }

  /// Returns all songs that have been searched and played, ordered by recency.
  List<SongInteraction> getSearchPlayedInteractions() {
    return _interactions.values
        .where((i) => i.searchPlayCount > 0 && !i.isArtistPreference)
        .toList()
      ..sort((a, b) => b.lastInteraction.compareTo(a.lastInteraction));
  }

  // --- Real-Time Implicit Signal Capture with PlaybackSession ---

  /// Called when a song begins playback. Starts a new PlaybackSession.
  void onSongStarted(Song song) {
    final now = _clock();

    // Check if previous session was abandoned or skipped early
    if (_activeSession != null && !_activeSession!.isTerminal) {
      final prev = _activeSession!;
      final elapsed = now.difference(prev.startTime).inSeconds;
      if (elapsed < 15 && prev.lastPosition.inSeconds < 15) {
        prev.outcome = SessionOutcome.skipped;
        _recordSkipInternal(prev.trackKey);
      } else {
        prev.outcome = SessionOutcome.abandoned;
      }
    }

    final key = _canonicalKeyForSong(song);
    _activeSession = PlaybackSession(
      trackKey: key,
      song: song,
      startTime: now,
      initialDuration: song.duration,
    );

    final interaction = _getOrCreateInteraction(song);
    interaction.recordPlay(now);

    _recalculateArtistAffinities();
    _scheduleSave();
    debugPrint('PulseIQ: Started playing "${song.title}" by "${song.artist}" (plays: ${interaction.playCount})');
  }

  /// Called on playback progress stream. Transitions session to completed once
  /// listening threshold (>= 80% or >= 3 minutes) is crossed.
  void onPlaybackProgress(Song song, Duration position, Duration duration) {
    if (_activeSession == null || _activeSession!.song.id != song.id) {
      _activeSession = PlaybackSession(
        trackKey: _canonicalKeyForSong(song),
        song: song,
        startTime: _clock(),
        initialDuration: duration,
      );
    }

    final session = _activeSession!;
    if (session.isTerminal) return;

    session.lastPosition = position;
    if (duration > Duration.zero) session.duration = duration;

    // Spotify rule: Listening past 80% or 3 minutes counts as an intentional complete play
    if (session.duration > Duration.zero) {
      final ratio = position.inMilliseconds / session.duration.inMilliseconds;
      if (ratio >= 0.80 || position.inSeconds >= 180) {
        session.outcome = SessionOutcome.completed;
        _recordCompletionInternal(session.trackKey, song);
      }
    }
  }

  /// Explicitly called when user initiates a manual skip before song naturally completes.
  void onSongSkipped(Song song, {bool isManual = true}) {
    final session = _activeSession;
    if (session != null && session.song.id == song.id) {
      if (session.outcome == SessionOutcome.completed) return; // Not a negative skip if completed
      if (session.outcome == SessionOutcome.skipped) return;
      session.outcome = SessionOutcome.skipped;
    }
    _recordSkipInternal(_canonicalKeyForSong(song));
  }

  /// Called when audio reaches natural completion (e.g. ProcessingState.completed).
  void onSongCompleted(Song song) {
    final session = _activeSession;
    if (session != null && session.song.id == song.id) {
      if (session.outcome == SessionOutcome.completed) return;
      session.outcome = SessionOutcome.completed;
    }
    _recordCompletionInternal(_canonicalKeyForSong(song), song);
  }

  /// Explicitly records when a track is marked or unmarked as favorite.
  void onSongFavoriteToggled(Song song, bool isFav) {
    final now = _clock();
    final interaction = _getOrCreateInteraction(song);
    interaction.recordFavorite(now, isFav);

    _recalculateArtistAffinities();
    _scheduleSave();
    debugPrint('PulseIQ: Recorded favorite=$isFav for "${song.title}" by "${song.artist}"');
  }

  void _recordCompletionInternal(String trackKey, Song song) {
    final now = _clock();
    final interaction = _getOrCreateInteraction(song);
    interaction.recordComplete(now);

    _recalculateArtistAffinities();
    _scheduleSave();
    debugPrint('PulseIQ: Recorded completion for "${song.title}" by "${song.artist}" (completed: ${interaction.completeCount} times)');
  }

  void _recordSkipInternal(String trackKey) {
    final now = _clock();
    final interaction = _interactions[trackKey];
    if (interaction != null) {
      interaction.recordSkip(now);
      _recalculateArtistAffinities();
      _scheduleSave();
      debugPrint('PulseIQ: Recorded skip penalty for "${interaction.title}" (skips: ${interaction.skipCount})');
    }
  }

  // --- Taste Metrics & Candidate Scoring ---

  int get trackedSongCount =>
      _interactions.values.where((i) => !i.isArtistPreference).length;
  int get trackedArtistCount {
    _recalculateArtistAffinities();
    return _artistAffinities.length;
  }

  /// Returns tracked songs sorted by affinity score descending.
  List<SongInteraction> getTrackedSongs({String? query}) {
    final now = _clock();
    var list = _interactions.values.where((i) => !i.isArtistPreference).toList()
      ..sort((a, b) => b.computeAffinityScore(now).compareTo(a.computeAffinityScore(now)));

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((i) =>
        i.title.toLowerCase().contains(q) ||
        i.artist.toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  /// Returns tracked artists paired with their affinity score.
  List<MapEntry<String, double>> getTrackedArtists({String? query}) {
    _recalculateArtistAffinities();
    var list = _artistAffinities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((e) => e.key.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  bool isSearchPlayedArtist(String artistToken) {
    return _searchPlayedArtists.contains(artistToken.toLowerCase().trim());
  }

  /// Removes an individual song interaction from taste recommendations.
  Future<bool> removeTrackedSong(String trackKey) async {
    final removed = _interactions.remove(trackKey);
    if (removed != null) {
      if (removed.songId != 0) {
        _songIdToTrackKey.remove(removed.songId);
      }
      _recalculateArtistAffinities();
      await flush();
      return true;
    }
    return false;
  }

  /// Removes all tracked interactions and affinity for an artist.
  Future<int> removeTrackedArtist(String artistName) async {
    final tokens = parseArtistTokens(artistName);
    if (tokens.isEmpty) return 0;

    int removedCount = 0;
    final keysToRemove = <String>[];

    for (final inter in _interactions.values) {
      final songTokens = parseArtistTokens(inter.artist);
      if (songTokens.any((t) => tokens.contains(t))) {
        keysToRemove.add(inter.trackKey);
      }
    }

    for (final key in keysToRemove) {
      final inter = _interactions.remove(key);
      if (inter != null && inter.songId != 0) {
        _songIdToTrackKey.remove(inter.songId);
      }
      removedCount++;
    }

    for (final token in tokens) {
      _artistAffinities.remove(token);
      _searchPlayedArtists.remove(token);
    }

    _recalculateArtistAffinities();
    await flush();
    return removedCount;
  }

  /// Manually adds or boosts a preferred artist in the taste profile.
  Future<void> addPreferredArtist(String artistName) async {
    final tokens = parseArtistTokens(artistName);
    if (tokens.isEmpty) return;

    final primaryToken = tokens.first;
    final dummyKey = '${SongInteraction.artistPreferencePrefix}$primaryToken';
    final now = _clock();

    _interactions[dummyKey] = SongInteraction(
      trackKey: dummyKey,
      songId: 0,
      title: 'Top Artist Selection',
      artist: artistName.trim(),
      playCount: 10,
      completeCount: 8,
      searchPlayCount: 3,
      lastInteraction: now,
      positiveScore: 35.0,
      negativeScore: 0.0,
    );

    for (final token in tokens) {
      _searchPlayedArtists.add(token);
      _artistAffinities[token] = (_artistAffinities[token] ?? 0.0) + 15.0;
    }

    _recalculateArtistAffinities();
    await flush();
  }

  /// Completely clears all tracked taste history, resetting recommendations.
  Future<void> clearTasteProfile() async {
    _interactions.clear();
    _songIdToTrackKey.clear();
    _artistAffinities.clear();
    _searchPlayedArtists.clear();
    _activeSession = null;
    try {
      final file = await _resolveStorageFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    debugPrint('PulseIQ: Taste profile cleared completely.');
  }

  /// Returns top artists sorted by dynamic affinity score.
  List<String> getTopArtists({int limit = 10}) {
    _recalculateArtistAffinities();
    final sorted = _artistAffinities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Scores a candidate song against the user's on-device taste profile.
  /// Normalizes individual signals and caps artist dominance (Findings 7, 8, 11).
  double scoreCandidate(
    JioSaavnItem candidate, {
    String? preferredLang,
    int coOccurrences = 1,
  }) {
    final now = _clock();
    double score = 1.0; // Base baseline

    // 1. Exact Artist Token Affinity check (Finding 7)
    final candidateTokens = parseArtistTokens(candidate.subtitle);
    double maxArtistAffinity = 0.0;
    for (final token in candidateTokens) {
      final aff = _artistAffinities[token] ?? 0.0;
      if (aff > maxArtistAffinity) {
        maxArtistAffinity = aff;
      }
    }
    // Cap artist influence to avoid single favorite artist dominating everything (Finding 11)
    score += (maxArtistAffinity * 1.5).clamp(0.0, 5.0);

    // 2. Track Interaction History (Finding 2, 11)
    final interaction = _getInteraction(candidate.canonicalKey, candidate.id);
    if (interaction != null) {
      final affinity = interaction.computeAffinityScore(now);
      score += affinity.clamp(0.0, 8.0);
      if (interaction.skipCount > interaction.completeCount) {
        score -= (interaction.skipCount * 2.0).clamp(0.0, 6.0);
      }
      // Highest priority signal: Tracks explicitly searched and played by user
      if (interaction.searchPlayCount > 0) {
        score += 25.0 + (interaction.searchPlayCount * 5.0).clamp(0.0, 25.0);
      }
    }

    // Direct affinity boost for candidates from artists that user searched and played
    for (final token in candidateTokens) {
      if (_searchPlayedArtists.contains(token)) {
        score += 5.0;
        break;
      }
    }

    // 3. Multi-seed co-occurrence boost (Finding 5)
    if (coOccurrences > 1) {
      score += (coOccurrences - 1) * 3.0;
    }

    // 4. Language preference score feature (Finding 8)
    if (preferredLang != null && preferredLang.isNotEmpty) {
      final candLang = candidate.language?.trim().toLowerCase();
      if (candLang != null && candLang.isNotEmpty) {
        if (candLang == preferredLang.trim().toLowerCase()) {
          score += 2.0; // Language match boost
        }
      }
    }

    return max(0.1, score);
  }

  /// True Maximal Marginal Relevance (MMR) Diversity Filter:
  /// Balances normalized relevance against similarity across artists, albums, and language,
  /// with a 10-20% exploration factor and a per-artist cap (Finding 6).
  List<JioSaavnItem> rankAndFilterWithMMR(
    List<JioSaavnItem> candidates, {
    String? preferredLang,
    double lambda = 0.7,
    int maxPerArtist = 2,
    int maxResults = 25,
    double explorationRate = 0.15,
    Map<String, int>? coOccurrenceMap,
  }) {
    if (candidates.isEmpty) return const [];

    // JioSaavn lists one song several times (per album / release, with
    // different ids and slightly different titles or artist credits). Collapse
    // those into one entry: the listing that scores best represents the song,
    // and the seeds that suggested any of its listings all count for it.
    final groups = <List<JioSaavnItem>>[];
    final groupFingerprints = <List<SongFingerprint>>[];
    for (final item in candidates) {
      final fingerprint = _fingerprintOf(item);
      var placed = false;
      for (var g = 0; g < groups.length && !placed; g++) {
        if (groupFingerprints[g].any(fingerprint.isSameSongAs)) {
          groups[g].add(item);
          groupFingerprints[g].add(fingerprint);
          placed = true;
        }
      }
      if (!placed) {
        groups.add([item]);
        groupFingerprints.add([fingerprint]);
      }
    }

    final scored = <(JioSaavnItem, double)>[];
    for (final group in groups) {
      final pooledSeeds = group.fold<int>(0, (sum, m) => sum + (coOccurrenceMap?[m.canonicalKey] ?? 0));
      final seedCount = max(1, pooledSeeds);
      JioSaavnItem? best;
      double bestScore = -double.infinity;
      for (final member in group) {
        final s = scoreCandidate(member, preferredLang: preferredLang, coOccurrences: seedCount);
        if (s > bestScore) {
          bestScore = s;
          best = member;
        }
      }
      scored.add((best!, bestScore));
    }
    // From here on, every listing of a song other than its representative is gone.
    candidates = scored.map((p) => p.$1).toList();

    double minScore = double.infinity;
    double maxScore = -double.infinity;
    for (final pair in scored) {
      if (pair.$2 < minScore) minScore = pair.$2;
      if (pair.$2 > maxScore) maxScore = pair.$2;
    }
    final range = max(0.001, maxScore - minScore);

    // Normalized relevance R(x) in [0, 1]
    final normalizedScores = Map<JioSaavnItem, double>.fromEntries(
      scored.map((p) => MapEntry(p.$1, (p.$2 - minScore) / range)),
    );

    final selected = <JioSaavnItem>[];
    final artistCounts = <String, int>{};
    final remaining = List<JioSaavnItem>.from(candidates);

    // Reserve exploration slots so MMR does not saturate all slots before exploration runs (Finding 4)
    final int totalExplorationSlots = (explorationRate > 0 && candidates.length > 1)
        ? (maxResults * explorationRate).round().clamp(1, max(1, maxResults ~/ 2)).toInt()
        : 0;
    final targetMMRSlots = max(1, maxResults - totalExplorationSlots);

    // Phase 1: Iterative MMR selection for relevance slots
    while (selected.length < targetMMRSlots && remaining.isNotEmpty) {
      JioSaavnItem? bestCandidate;
      double bestMMR = -double.infinity;

      for (final candidate in remaining) {
        final primaryArtist = parseArtistTokens(candidate.subtitle).firstOrNull ?? '';
        final count = artistCounts[primaryArtist] ?? 0;
        final inter = _getInteraction(candidate.canonicalKey, candidate.id);
        final isSearchPlayed = (inter?.searchPlayCount ?? 0) > 0;
        if (!isSearchPlayed && primaryArtist.isNotEmpty && count >= maxPerArtist) {
          continue; // Enforce artist quota on recommendations, not explicit user search plays
        }

        final relevance = normalizedScores[candidate] ?? 0.0;
        double maxSim = 0.0;

        for (final sel in selected) {
          final sim = _computeSimilarity(candidate, sel);
          if (sim > maxSim) maxSim = sim;
        }

        final mmr = (lambda * relevance) - ((1.0 - lambda) * maxSim);
        if (mmr > bestMMR) {
          bestMMR = mmr;
          bestCandidate = candidate;
        }
      }

      if (bestCandidate != null) {
        selected.add(bestCandidate);
        remaining.remove(bestCandidate);
        final primaryArtist = parseArtistTokens(bestCandidate.subtitle).firstOrNull ?? '';
        if (primaryArtist.isNotEmpty) {
          artistCounts[primaryArtist] = (artistCounts[primaryArtist] ?? 0) + 1;
        }
      } else {
        // Quota saturated for top artists; break to exploration/fill
        break;
      }
    }

    // Phase 2: Fill exploration slots with novel artists not yet selected (Finding 4)
    if (totalExplorationSlots > 0 && selected.length < maxResults && remaining.isNotEmpty) {
      final existingArtists = selected.map((s) => parseArtistTokens(s.subtitle).firstOrNull ?? '').toSet();
      // Best-scoring new artists first, not whatever happens to be first in
      // the pool (that picked the least related songs on purpose).
      final novelCandidates = remaining.where((c) {
        final artist = parseArtistTokens(c.subtitle).firstOrNull ?? '';
        return artist.isNotEmpty && !existingArtists.contains(artist);
      }).toList()
        ..sort((a, b) => (normalizedScores[b] ?? 0.0).compareTo(normalizedScores[a] ?? 0.0));
      novelCandidates.removeRange(min(totalExplorationSlots, novelCandidates.length), novelCandidates.length);

      for (final novel in novelCandidates) {
        if (selected.length >= maxResults) break;
        selected.add(novel);
        remaining.remove(novel);
        final primaryArtist = parseArtistTokens(novel.subtitle).firstOrNull ?? '';
        if (primaryArtist.isNotEmpty) {
          artistCounts[primaryArtist] = (artistCounts[primaryArtist] ?? 0) + 1;
        }
      }
    }

    // Phase 3: Fill any remaining slots up to maxResults with next best remaining candidates
    while (selected.length < maxResults && remaining.isNotEmpty) {
      JioSaavnItem? fallbackCandidate;
      for (final candidate in remaining) {
        final primaryArtist = parseArtistTokens(candidate.subtitle).firstOrNull ?? '';
        final count = artistCounts[primaryArtist] ?? 0;
        final inter = _getInteraction(candidate.canonicalKey, candidate.id);
        final isSearchPlayed = (inter?.searchPlayCount ?? 0) > 0;
        if (isSearchPlayed || primaryArtist.isEmpty || count < maxPerArtist) {
          fallbackCandidate = candidate;
          break;
        }
      }
      if (fallbackCandidate == null) {
        break; // Quota saturated for all remaining candidates; preserve artist diversity limits
      }

      selected.add(fallbackCandidate);
      remaining.remove(fallbackCandidate);
      final primaryArtist = parseArtistTokens(fallbackCandidate.subtitle).firstOrNull ?? '';
      if (primaryArtist.isNotEmpty) {
        artistCounts[primaryArtist] = (artistCounts[primaryArtist] ?? 0) + 1;
      }
    }

    return selected;
  }

  static SongFingerprint _fingerprintOf(JioSaavnItem item) => SongFingerprint.of(
        identity: item.canonicalKey,
        title: item.title,
        artist: item.subtitle,
        durationSecs: int.tryParse(item.duration ?? '') ?? 0,
      );

  /// True when [a] and [b] are two listings of the same song.
  static bool isSameSong(JioSaavnItem a, JioSaavnItem b) =>
      _fingerprintOf(a).isSameSongAs(_fingerprintOf(b));

  /// Calculates content similarity between two JioSaavn items in [0, 1].
  double _computeSimilarity(JioSaavnItem a, JioSaavnItem b) {
    double sim = 0.0;
    final aArtists = parseArtistTokens(a.subtitle).toSet();
    final bArtists = parseArtistTokens(b.subtitle).toSet();
    if (aArtists.intersection(bArtists).isNotEmpty) {
      sim += 0.6;
    }
    if (a.music != null && b.music != null && a.music!.isNotEmpty && a.music == b.music) {
      sim += 0.3;
    }
    if (a.language != null && b.language != null && a.language!.toLowerCase() == b.language!.toLowerCase()) {
      sim += 0.1;
    }
    return min(1.0, sim);
  }

  // --- Seed Resolution Matching (Finding 5) ---

  /// Resolves the authentic provider item for a seed song using fuzzy title similarity,
  /// artist token overlap, and duration tolerance.
  static JioSaavnItem? findBestSeedMatch(Song seed, List<JioSaavnItem> candidates) {
    if (candidates.isEmpty) return null;

    final seedTitleClean = _cleanText(seed.title);
    final seedArtistTokens = parseArtistTokens(seed.artist).toSet();
    final seedDurSecs = seed.duration.inSeconds;

    JioSaavnItem? bestMatch;
    double bestScore = -1.0;

    for (final item in candidates) {
      if (!item.isSong || item.title.trim().isEmpty) continue;
      final candTitleClean = _cleanText(item.title);
      final candArtistTokens = parseArtistTokens(item.subtitle).toSet();

      // Title match
      final titleSim = _stringSimilarity(seedTitleClean, candTitleClean);

      // Artist overlap. A song is only the SAME song if an artist agrees:
      // two songs sharing a title (another artist's "Kesariya", a dub in
      // another language) are different songs. Without this, a same-titled
      // song by someone else won the match and became the seed, so the
      // suggestions came from the wrong song entirely.
      final overlap = seedArtistTokens.intersection(candArtistTokens);
      if (seedArtistTokens.isNotEmpty && candArtistTokens.isNotEmpty && overlap.isEmpty) {
        continue;
      }
      final artistSim = seedArtistTokens.isNotEmpty
          ? overlap.length / seedArtistTokens.length
          : 0.5;

      // Duration tolerance
      double durationSim = 0.5;
      final candDur = int.tryParse(item.duration ?? '0') ?? 0;
      if (seedDurSecs > 0 && candDur > 0) {
        final diff = (seedDurSecs - candDur).abs();
        if (diff <= 15) {
          durationSim = 1.0;
        } else if (diff <= 45) {
          durationSim = 0.7;
        } else {
          durationSim = 0.2;
        }
      }

      final score = (titleSim * 0.55) + (artistSim * 0.30) + (durationSim * 0.15);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }

    // No convincing match: return nothing rather than an unrelated first
    // result (which could even be an album/artist). Callers then fall back to
    // artist / language based candidates instead of seeding from a wrong song.
    return bestScore >= 0.40 ? bestMatch : null;
  }

  static String _cleanText(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
  }

  static double _stringSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final aWords = a.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    final bWords = b.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    final intersection = aWords.intersection(bWords).length;
    final union = aWords.union(bWords).length;
    return union > 0 ? intersection / union : 0.0;
  }

  // --- Multi-Seed & Radar Candidate Retrieval ---

  Future<Map<JioSaavnItem, int>> fetchMultiSeedCandidates(
    List<Song> seedSongs, {
    int perSeedLimit = 15,
  }) async {
    final Map<String, (JioSaavnItem, int)> occurrences = {};

    final futures = seedSongs.take(3).map((song) async {
      try {
        final query = '${song.title} ${song.artist}'.trim();
        final searchResults = await _searchSongs(query);
        final match = findBestSeedMatch(song, searchResults);
        final seedId = match != null ? (match.id.isNotEmpty ? match.id : match.token) : null;

        if (seedId != null && seedId.isNotEmpty) {
          final suggestions = await _fetchSuggestions(seedId, limit: perSeedLimit);
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
        final key = item.canonicalKey;
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

  Future<List<JioSaavnItem>> fetchComposerAndCollaborationRadar(
    List<Song> topSongs, {
    int perCreatorLimit = 10,
    int maxCreators = 3,
  }) async {
    final List<JioSaavnItem> radarCandidates = [];
    final Set<String> targetCreators = {};

    for (final song in topSongs) {
      if (targetCreators.length >= maxCreators) break;
      final tokens = parseArtistTokens(song.artist);
      for (final token in tokens) {
        if (targetCreators.length < maxCreators && !targetCreators.contains(token)) {
          targetCreators.add(token);
        }
      }
    }

    final futures = targetCreators.map((creator) async {
      try {
        final results = await _searchSongs(creator);
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

  // --- Unified Recommendation Engine (Findings 9 & 10) ---

  /// Single unified entry point for all recommendation surfaces (Home, Radio, Autoplay).
  /// Excludes queue tracks, recent history, and current session (Finding 10).
  Future<List<Song>> getRecommendations({
    required RecommendationContext context,
    Song? currentSong,
    List<Song> queue = const [],
    List<Song> recentHistory = const [],
    List<Song> favorites = const [],
    String lang = 'hindi',
    int limit = 15,
  }) async {
    final candidateItems = await getCandidateRecommendations(
      context: context,
      currentSong: currentSong,
      queue: queue,
      recentHistory: recentHistory,
      favorites: favorites,
      lang: lang,
      limit: limit,
    );

    return candidateItems
        .map((item) => item.toSong())
        .where((s) => s.filePath.trim().isNotEmpty || s.source == 'jiosaavn')
        .toList();
  }

  /// How many songs by one main artist a result may hold.
  ///
  /// The usual cap is 2, to keep a queue varied. But JioSaavn's suggestions
  /// for a song are often one artist's catalogue (all 20 results by the same
  /// artist), and a fixed cap of 2 then threw away nearly all of them and
  /// left Autoplay with 3 songs. When the pool has so few distinct main artists
  /// that a cap of 2 could not fill [limit] (artists x 2 < limit), the cap is
  /// lifted so the pool can fill it; a varied pool keeps the cap of 2.
  int _adaptiveArtistCap(List<JioSaavnItem> candidates, int limit) {
    final artists = <String>{
      for (final c in candidates) parseArtistTokens(c.subtitle).firstOrNull ?? '',
    }..remove('');
    if (artists.isEmpty) return 2;
    return artists.length * 2 < limit ? limit : 2;
  }

  /// Other songs by every artist credited on [seedSongId] (JioSaavn
  /// `search.artistOtherTopSongs`, one call per artist), combined. Failures
  /// for one artist never affect the others.
  Future<List<JioSaavnItem>> _fetchCreditedArtistsSongs(String seedSongId, {required String lang}) async {
    try {
      final artists = await _fetchSongArtists(seedSongId);
      if (artists.isEmpty) return const [];
      final lists = await Future.wait(artists.take(4).map((a) async {
        try {
          return await _fetchArtistSongs(a.id, seedSongId, lang: lang);
        } catch (_) {
          return <JioSaavnItem>[];
        }
      }));
      return [for (final l in lists) ...l.where((i) => i.isSong && i.title.trim().isNotEmpty)];
    } catch (e) {
      debugPrint('PulseIQ: artist songs lookup failed: $e');
      return const [];
    }
  }

  /// Retrieves and ranks raw candidate JioSaavnItems through the unified PulseIQ pipeline.
  Future<List<JioSaavnItem>> getCandidateRecommendations({
    required RecommendationContext context,
    Song? currentSong,
    List<Song> queue = const [],
    List<Song> recentHistory = const [],
    List<Song> favorites = const [],
    String lang = 'hindi',
    int limit = 15,
  }) async {
    try {
      // 1. Build excluded canonical key and title sets (Finding 10)
      final Set<String> excludedKeys = {};
      final Set<String> excludedTitles = {};

      void addExclusion(Song? song) {
        if (song == null) return;
        excludedKeys.add(song.canonicalKey);
        final title = song.title.trim().toLowerCase();
        if (title.isNotEmpty) excludedTitles.add(title);
      }

      addExclusion(currentSong);
      for (final q in queue) {
        addExclusion(q);
      }
      for (final r in recentHistory) {
        addExclusion(r);
      }

      List<JioSaavnItem> pool = [];
      final Map<String, int> coOccurrences = {};
      var radioWidened = false;

      // 2. Candidate retrieval based on context
      if (context == RecommendationContext.autoplay || context == RecommendationContext.radio) {
        // Single-seed mode around currentSong with fallback
        if (currentSong != null) {
          // Direct ID lookup if mediaId exists (or if source is jiosaavn)
          final directId = (currentSong.mediaId != null && currentSong.mediaId!.isNotEmpty)
              ? currentSong.mediaId!
              : (currentSong.source == 'jiosaavn' && currentSong.id != 0 ? currentSong.id.toString() : null);

          String? resolvedSeedId;
          if (directId != null && directId.isNotEmpty) {
            pool = await _fetchSuggestions(directId, limit: max(30, limit * 2));
            resolvedSeedId = directId;
          }

          if (pool.isEmpty) {
            final query = '${currentSong.title} ${currentSong.artist}'.trim();
            final searchResults = await _searchSongs(query);
            final seedMatch = findBestSeedMatch(currentSong, searchResults);
            final seedId = seedMatch != null ? (seedMatch.id.isNotEmpty ? seedMatch.id : seedMatch.token) : null;

            if (seedId != null && seedId.isNotEmpty) {
              pool = await _fetchSuggestions(seedId, limit: max(30, limit * 2));
              resolvedSeedId = seedId;
            }
          }

          // Radio widens the pool with each credited artist's other songs,
          // because the suggestions alone are usually one artist's catalogue.
          if (context == RecommendationContext.radio && resolvedSeedId != null) {
            final more = await _fetchCreditedArtistsSongs(resolvedSeedId, lang: lang);
            if (more.isNotEmpty) {
              pool = [...pool, ...more];
              radioWidened = true;
            }
          }
        }

        // Fallback to the user's top artist if single-seed suggestions are
        // sparse. The playing song's own artist field is only trusted for
        // JioSaavn songs: for YouTube downloads it is the channel name (e.g.
        // "T-Series"), and searching that returns aartis and bhajans.
        if (pool.length < 5) {
          final topArtists = getTopArtists(limit: 3);
          final fallbackArtist = topArtists.isNotEmpty
              ? topArtists.first
              : (currentSong != null && currentSong.source == 'jiosaavn' ? currentSong.artist : '');
          if (fallbackArtist.isNotEmpty && fallbackArtist.toLowerCase() != 'unknown') {
            final artistResults = await _searchSongs(fallbackArtist);
            pool.addAll(artistResults.where((i) => i.isSong));
          }
        }

        // Last resort: current releases in the user's language. Searching the
        // literal word ("hindi") matched random devotional / kids tracks.
        if (pool.isEmpty) {
          final effectiveLang = lang.isNotEmpty ? lang : 'hindi';
          var langResults = await _fetchNewReleases(lang: effectiveLang);
          if (langResults.where((i) => i.isSong).isEmpty) {
            langResults = await _searchSongs(effectiveLang);
          }
          pool.addAll(langResults.where((i) => i.isSong));
        }
      } else {
        // Home multi-seed mode (Search-played songs highest priority, then favorites, then top history)
        final List<Song> seeds = [];
        // Seeds are told apart by song identity, not title: two different
        // songs with the same name must both be able to seed.
        final seenSeedTitles = <String>{};

        final searchPlayedSongs = getSearchPlayedInteractions()
            .map((i) => i.toJioSaavnItem().toSong())
            .toList();

        for (final song in [...searchPlayedSongs, ...favorites, ...recentHistory]) {
          if (seeds.length >= 4) break;
          if (song.title.trim().isEmpty) continue;
          if (seenSeedTitles.add(song.canonicalKey)) {
            seeds.add(song);
          }
        }

        if (seeds.isEmpty) {
          try {
            var popular = (await _fetchNewReleases(lang: lang)).where((i) => i.isSong).toList();
            if (popular.isEmpty) popular = await _searchSongs(lang);
            seeds.addAll(popular.take(3).map((item) => item.toSong()));
          } catch (_) {}
        }

        if (seeds.isNotEmpty) {
          final multiSeedFuture = fetchMultiSeedCandidates(seeds, perSeedLimit: 15);
          final composerRadarFuture = fetchComposerAndCollaborationRadar(seeds, perCreatorLimit: 8, maxCreators: 3);
          final combined = await Future.wait([multiSeedFuture, composerRadarFuture]);
          final multiSeedMap = combined[0] as Map<JioSaavnItem, int>;
          final composerCandidates = combined[1] as List<JioSaavnItem>;

          final Map<String, JioSaavnItem> deduplicated = {};
          for (final entry in multiSeedMap.entries) {
            final key = entry.key.canonicalKey;
            deduplicated[key] = entry.key;
            coOccurrences[key] = (coOccurrences[key] ?? 0) + entry.value;
          }
          for (final item in composerCandidates) {
            final key = item.canonicalKey;
            deduplicated[key] = item;
            coOccurrences[key] = (coOccurrences[key] ?? 0) + 1;
          }
          // Direct injection of user's searched and played songs into candidate pool
          for (final sp in getSearchPlayedInteractions()) {
            final item = sp.toJioSaavnItem();
            final key = item.canonicalKey;
            deduplicated[key] = item;
            coOccurrences[key] = (coOccurrences[key] ?? 0) + 3;
          }
          pool = deduplicated.values.toList();
        }
      }

      // Content-type guard: devotional / kids tracks only when the song being
      // played is that kind, or the user has explicitly chosen that kind.
      final allowedCategories = _explicitlyChosenCategories();
      final seedCategory = currentSong != null ? ContentClassifier.ofSong(currentSong) : null;
      if (seedCategory != null) allowedCategories.add(seedCategory);
      pool = pool.where((item) {
        final category = ContentClassifier.ofItem(item);
        return category == null || allowedCategories.contains(category);
      }).toList();

      var candidateList = pool.where((item) {
        if (!item.isSong || item.title.trim().isEmpty) return false;
        final inter = _getInteraction(item.canonicalKey, item.id);
        final isSearchPlayed = (inter?.searchPlayCount ?? 0) > 0;
        // In home recommendation mode, songs the user explicitly searched and played
        // are never filtered out by recent history exclusions
        if (context == RecommendationContext.home && isSearchPlayed) {
          return true;
        }
        if (excludedKeys.contains(item.canonicalKey)) return false;
        if (excludedTitles.contains(item.title.trim().toLowerCase())) return false;
        return true;
      }).toList();

      // If autoplay or radio has no candidates after history filter, fallback to only queue exclusions
      if (candidateList.isEmpty && (context == RecommendationContext.autoplay || context == RecommendationContext.radio)) {
        final queueKeys = queue.map((s) => s.canonicalKey).toSet();
        final queueTitles = queue.map((s) => s.title.trim().toLowerCase()).toSet();
        if (currentSong != null) {
          queueKeys.add(currentSong.canonicalKey);
          queueTitles.add(currentSong.title.trim().toLowerCase());
        }
        candidateList = pool.where((item) {
          if (!item.isSong || item.title.trim().isEmpty) return false;
          if (queueKeys.contains(item.canonicalKey)) return false;
          if (queueTitles.contains(item.title.trim().toLowerCase())) return false;
          return true;
        }).toList();
      }

      if (candidateList.isEmpty) {
        debugPrint('PulseIQ: All candidates excluded by queue/history filter.');
        return const [];
      }
      final candidatesToScore = candidateList;

      // 4. Re-rank with true iterative MMR, co-occurrence, and language weighting (Findings 4, 5, 6 & 8)
      final ranked = rankAndFilterWithMMR(
        candidatesToScore,
        preferredLang: lang,
        lambda: 0.7,
        // A widened radio pool is deliberately artist-heavy (the seed's own
        // artists), so the usual 2-per-artist cap would throw most of it away.
        maxPerArtist: radioWidened ? max(6, _adaptiveArtistCap(candidatesToScore, limit)) : _adaptiveArtistCap(candidatesToScore, limit),
        maxResults: limit,
        // Autoplay / Radio continue what the user is listening to, so no
        // deliberate "discovery" picks there; Home keeps a little exploration.
        explorationRate: context == RecommendationContext.home ? 0.15 : 0.0,
        coOccurrenceMap: coOccurrences,
      );

      debugPrint('PulseIQ: Recommended ${ranked.length} tracks for context $context.');
      return ranked;
    } catch (e) {
      debugPrint('PulseIQ getCandidateRecommendations error: $e');
      return [];
    }
  }

  /// Content categories of songs the user deliberately chose (searched and
  /// played, or favorited). Plain plays don't count: an autoplayed aarti that
  /// slipped through once must not unlock more of them.
  Set<ContentCategory> _explicitlyChosenCategories() {
    final categories = <ContentCategory>{};
    for (final inter in _interactions.values) {
      if (inter.isArtistPreference) continue;
      if (inter.searchPlayCount == 0 && !inter.isFavorite) continue;
      final category = ContentClassifier.classify('${inter.title} ${inter.artist}');
      if (category != null) categories.add(category);
    }
    return categories;
  }

  /// Backward-compatible wrapper for StreamScreen.
  Future<List<JioSaavnItem>> getPersonalizedSuggestions({
    required List<Song> topPlayed,
    required List<Song> streamHistory,
    List<Song> favorites = const [],
    String lang = 'hindi',
    int limit = 15,
  }) async {
    return getCandidateRecommendations(
      context: RecommendationContext.home,
      recentHistory: [...topPlayed, ...streamHistory],
      favorites: favorites,
      lang: lang,
      limit: limit,
    );
  }

  /// Backward-compatible wrapper for Smart Autoplay.
  Future<List<Song>> getSmartAutoplayRecommendations(
    Song currentSong, {
    int limit = 10,
  }) async {
    return getRecommendations(
      context: RecommendationContext.autoplay,
      currentSong: currentSong,
      limit: limit,
    );
  }

  // --- Persistence & Lifecycle Flush (Finding 12) ---

  void _scheduleSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(seconds: 3), flush);
  }

  /// Immediately writes pending taste profile interactions to disk.
  Future<void> flush() async {
    _saveDebounceTimer?.cancel();
    try {
      final file = await _resolveStorageFile();
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      final interactionList = _interactions.values.map((i) => i.toJson()).toList();
      final data = {
        'interactions': interactionList,
      };
      await file.writeAsString(jsonEncode(data));
      _recalculateArtistAffinities();
    } catch (e, st) {
      debugPrint('PulseIQ: Failed to flush taste profile: $e\n$st');
    }
  }

  void dispose() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = null;
  }
}
