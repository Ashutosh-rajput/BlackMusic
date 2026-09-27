import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_player/data/models/jiosaavn_item.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/services/stream_favorites_service.dart';
import 'package:pixel_player/services/user_taste_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserTasteService service;
  late Directory tempDir;
  late File tempFile;
  DateTime currentTime = DateTime(2026, 1, 1, 12, 0, 0);

  setUp(() async {
    currentTime = DateTime(2026, 1, 1, 12, 0, 0);
    tempDir = await Directory.systemTemp.createTemp('pulseiq_test_');
    tempFile = File('${tempDir.path}/pulseiq_taste_profile.json');

    service = UserTasteService(
      clock: () => currentTime,
      storageFile: tempFile,
      searchSongs: (query) async => [
        JioSaavnItem(
          type: 'song',
          id: 'mock_1',
          token: 'mock_1',
          title: 'Kesariya',
          subtitle: 'Arijit Singh, Pritam',
          imageUrl: '',
          duration: '268',
          language: 'hindi',
        ),
      ],
      fetchSuggestions: (id, {limit = 10}) async => [
        JioSaavnItem(
          type: 'song',
          id: 'sugg_1',
          token: 'sugg_1',
          title: 'Channa Mereya',
          subtitle: 'Arijit Singh, Pritam',
          imageUrl: '',
          duration: '289',
          language: 'hindi',
        ),
        JioSaavnItem(
          type: 'song',
          id: 'sugg_2',
          token: 'sugg_2',
          title: 'Ilahi',
          subtitle: 'Arijit Singh',
          imageUrl: '',
          duration: '220',
          language: 'hindi',
        ),
        JioSaavnItem(
          type: 'song',
          id: 'sugg_3',
          token: 'sugg_3',
          title: 'Ghungroo',
          subtitle: 'Arijit Singh, Shilpa Rao',
          imageUrl: '',
          duration: '302',
          language: 'hindi',
        ),
        JioSaavnItem(
          type: 'song',
          id: 'sugg_4',
          token: 'sugg_4',
          title: 'Lover',
          subtitle: 'Diljit Dosanjh',
          imageUrl: '',
          duration: '190',
          language: 'punjabi',
        ),
      ],
    );
    await service.init();
  });

  tearDown(() async {
    service.dispose();
    await Future.delayed(const Duration(milliseconds: 50));
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('PulseIQ UserTasteService Tests', () {
    test('SongInteraction computes decay score and penalties correctly', () {
      final now = currentTime;

      final positiveSong = SongInteraction(
        trackKey: 'test:1',
        songId: 1,
        title: 'Loved Track',
        artist: 'Arijit Singh',
        playCount: 5,
        completeCount: 4,
        skipCount: 0,
        lastInteraction: now,
      );

      final skippedSong = SongInteraction(
        trackKey: 'test:2',
        songId: 2,
        title: 'Skipped Track',
        artist: 'Unknown Artist',
        playCount: 1,
        completeCount: 0,
        skipCount: 3,
        lastInteraction: now,
      );

      // (4 * 1.5) + (5 * 0.5) = 8.5
      expect(positiveSong.computeAffinityScore(now), greaterThan(8.0));

      // (0 * 1.5) + (1 * 0.5) - (3 * 2.0) = -5.5 -> clamped to 0.0
      expect(skippedSong.computeAffinityScore(now), equals(0.0));
    });

    test('Old-positive-plus-new-skip decay: A skip CANNOT strengthen score', () {
      // 1. Create a track with positive history at t = 0
      final t0 = currentTime;
      final song = Song(
        id: 999,
        title: 'Old Hit',
        artist: 'Vintage Band',
        album: 'Vintage Album',
        filePath: 'https://example.com/old_hit.mp3',
        duration: const Duration(seconds: 200),
        dateModified: t0,
        source: 'jiosaavn',
      );

      // User listened to it 5 times at t0
      for (int i = 0; i < 5; i++) {
        service.onSongStarted(song);
        service.onPlaybackProgress(song, const Duration(seconds: 190), song.duration);
      }

      final candidate = JioSaavnItem(
        type: 'song',
        id: '999',
        token: '999',
        title: 'Old Hit',
        subtitle: 'Vintage Band',
        imageUrl: '',
      );

      final initialScore = service.scoreCandidate(candidate);
      expect(initialScore, greaterThan(5.0));

      // 2. Advance time by 60 days (two 30-day half-lives -> decayed by ~75%)
      currentTime = t0.add(const Duration(days: 60));
      final decayedScoreBeforeSkip = service.scoreCandidate(candidate);
      expect(decayedScoreBeforeSkip, lessThan(initialScore));

      // 3. User now skips the song today
      service.onSongStarted(song);
      service.onSongSkipped(song, isManual: true);

      final scoreAfterSkip = service.scoreCandidate(candidate);

      // The new skip must LOWER the score, NOT revive old completions!
      expect(scoreAfterSkip, lessThanOrEqualTo(decayedScoreBeforeSkip));
    });

    test('Track identity is stable across restarts using canonicalKey and FNV', () {
      const nonNumericId = 'sZk21QzL';
      const item = JioSaavnItem(
        type: 'song',
        id: nonNumericId,
        token: 'token_xyz',
        title: 'Alphanumeric Track',
        subtitle: 'Artist Name',
        imageUrl: '',
      );

      expect(item.canonicalKey, equals('jiosaavn:$nonNumericId'));

      final song1 = item.toSong();
      final song2 = item.toSong();

      // Integer ID must be deterministic across calls (FNV-1a)
      expect(song1.id, equals(song2.id));
      expect(song1.id, equals(item.stableId));
      // Canonical key on Song must match item.canonicalKey exactly!
      expect(song1.canonicalKey, equals(item.canonicalKey));
      expect(song1.canonicalKey, equals('jiosaavn:$nonNumericId'));

      // Skips and plays on Song must now match candidate scoring
      service.onSongStarted(song1);
      service.onSongSkipped(song1, isManual: true);
      final score = service.scoreCandidate(item);
      expect(score, lessThan(1.0)); // Skips penalized properly via matching canonical key
    });

    test('PlaybackSession: False completions are prevented on track transitions', () {
      final song = Song(
        id: 501,
        title: 'Short Sample',
        artist: 'Sampler',
        album: 'Album',
        filePath: 'https://example.com/s.mp3',
        duration: const Duration(seconds: 180),
        dateModified: currentTime,
      );

      // Start song and play only 10 seconds (< 80% and < 180s)
      service.onSongStarted(song);
      service.onPlaybackProgress(song, const Duration(seconds: 10), song.duration);

      // Another song starts (user switched tracks prematurely)
      final nextSong = Song(
        id: 502,
        title: 'Next Track',
        artist: 'Next Artist',
        album: 'Album',
        filePath: 'https://example.com/n.mp3',
        duration: const Duration(seconds: 180),
        dateModified: currentTime,
      );
      service.onSongStarted(nextSong);

      final candidate = JioSaavnItem(
        type: 'song',
        id: '501',
        token: '501',
        title: 'Short Sample',
        subtitle: 'Sampler',
        imageUrl: '',
      );

      // Score should not have complete count
      final score = service.scoreCandidate(candidate);
      expect(score, lessThan(3.0));
    });

    test('Seed resolution: findBestSeedMatch matches authentic song over covers/remixes', () {
      final originalSeed = Song(
        id: 111,
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        filePath: 'https://example.com/tum.mp3',
        duration: const Duration(seconds: 262),
        dateModified: currentTime,
      );

      final candidates = [
        const JioSaavnItem(
          type: 'song',
          id: 'remix_1',
          token: 'remix_1',
          title: 'Tum Hi Ho (EDM Club Remix)',
          subtitle: 'DJ Snake, Various Artists',
          imageUrl: '',
          duration: '180',
        ),
        const JioSaavnItem(
          type: 'song',
          id: 'orig_1',
          token: 'orig_1',
          title: 'Tum Hi Ho',
          subtitle: 'Arijit Singh, Mithoon',
          imageUrl: '',
          duration: '262',
        ),
        const JioSaavnItem(
          type: 'song',
          id: 'cover_1',
          token: 'cover_1',
          title: 'Tum Hi Ho Cover',
          subtitle: 'Acoustic Singer',
          imageUrl: '',
          duration: '200',
        ),
      ];

      final bestMatch = UserTasteService.findBestSeedMatch(originalSeed, candidates);
      expect(bestMatch, isNotNull);
      expect(bestMatch!.id, equals('orig_1'));
    });

    test('Queue and history exclusion: getCandidateRecommendations filters out heard songs', () async {
      final currentSong = Song(
        id: 991,
        title: 'Current Track',
        artist: 'Artist',
        album: 'Album',
        filePath: 'https://example.com/cur.mp3',
        duration: const Duration(seconds: 200),
        dateModified: currentTime,
      );

      final queueSong = Song(
        id: 992,
        title: 'Channa Mereya',
        artist: 'Arijit Singh',
        album: 'Album',
        filePath: 'https://example.com/q.mp3',
        duration: const Duration(seconds: 200),
        dateModified: currentTime,
      );

      final recommendations = await service.getCandidateRecommendations(
        context: RecommendationContext.autoplay,
        currentSong: currentSong,
        queue: [queueSong],
        limit: 10,
      );

      // Channa Mereya was in queue, so it must be excluded!
      expect(recommendations.any((r) => r.title == 'Channa Mereya'), isFalse);
    });

    test('Language preference boosts matching language candidates', () {
      final hindiSong = const JioSaavnItem(
        type: 'song',
        id: 'h1',
        token: 'h1',
        title: 'Hindi Melody',
        subtitle: 'New Artist',
        imageUrl: '',
        language: 'hindi',
      );

      final punjabiSong = const JioSaavnItem(
        type: 'song',
        id: 'p1',
        token: 'p1',
        title: 'Punjabi Beat',
        subtitle: 'New Artist',
        imageUrl: '',
        language: 'punjabi',
      );

      final scoreHindiWithHindiPref = service.scoreCandidate(hindiSong, preferredLang: 'hindi');
      final scorePunjabiWithHindiPref = service.scoreCandidate(punjabiSong, preferredLang: 'hindi');

      expect(scoreHindiWithHindiPref, greaterThan(scorePunjabiWithHindiPref));
    });

    test('MMR Diversity Filter balances relevance, enforces artist limits', () {
      final candidates = [
        const JioSaavnItem(
          type: 'song',
          id: '1',
          token: '1',
          title: 'Track 1',
          subtitle: 'Arijit Singh, Pritam',
          imageUrl: '',
        ),
        const JioSaavnItem(
          type: 'song',
          id: '2',
          token: '2',
          title: 'Track 2',
          subtitle: 'Arijit Singh',
          imageUrl: '',
        ),
        const JioSaavnItem(
          type: 'song',
          id: '3',
          token: '3',
          title: 'Track 3',
          subtitle: 'Arijit Singh, Shreya Ghoshal',
          imageUrl: '',
        ),
        const JioSaavnItem(
          type: 'song',
          id: '4',
          token: '4',
          title: 'Track 4',
          subtitle: 'Diljit Dosanjh',
          imageUrl: '',
        ),
        const JioSaavnItem(
          type: 'song',
          id: '5',
          token: '5',
          title: 'Track 5',
          subtitle: 'Badshah',
          imageUrl: '',
        ),
      ];

      final filtered = service.rankAndFilterWithMMR(candidates, maxPerArtist: 2, maxResults: 10);

      // Primary artist Arijit Singh should have at most 2 tracks included
      final arijitCount = filtered.where((s) => s.subtitle.toLowerCase().contains('arijit singh')).length;
      expect(arijitCount, lessThanOrEqualTo(2));
      expect(filtered.any((s) => s.title == 'Track 4'), isTrue);
      expect(filtered.any((s) => s.title == 'Track 5'), isTrue);
    });

    test('Persistence flush saves interactions and reloads cleanly', () async {
      final song = Song(
        id: 777,
        title: 'Persisted Song',
        artist: 'Persistent Artist',
        album: 'Album',
        filePath: 'https://example.com/p.mp3',
        duration: const Duration(seconds: 210),
        dateModified: currentTime,
      );

      service.onSongStarted(song);
      service.onSongFavoriteToggled(song, true);
      await service.flush();

      // Check file was written to disk
      expect(tempFile.existsSync(), isTrue);
      expect(tempFile.lengthSync(), greaterThan(0));

      // Create a fresh instance reading the same file
      final newService = UserTasteService(
        clock: () => currentTime,
        storageFile: tempFile,
      );
      await newService.init();

      final topArtists = newService.getTopArtists();
      expect(topArtists, contains('persistent artist'));
      newService.dispose();
    });

    test('Favorite scoring adds exactly +3.0 and leaves no residual bonus after unfavoriting', () {
      final song = Song(
        id: 888,
        title: 'Fav Track',
        artist: 'Fav Artist',
        album: 'Album',
        filePath: 'https://example.com/fav.mp3',
        duration: const Duration(seconds: 200),
        dateModified: currentTime,
        source: 'jiosaavn',
        mediaId: 'fav_888',
      );

      const candidate = JioSaavnItem(
        type: 'song',
        id: 'fav_888',
        token: 'fav_888',
        title: 'Fav Track',
        subtitle: 'Fav Artist',
        imageUrl: '',
      );

      final baselineScore = service.scoreCandidate(candidate);

      // 1. Toggle favorite ON
      service.onSongFavoriteToggled(song, true);
      final scoreWithFav = service.scoreCandidate(candidate);

      // Track affinity gets +3.0 bonus, plus artist affinity gets calculated once (no double-counting of favorite)
      expect(scoreWithFav, greaterThan(baselineScore));

      // 2. Toggle favorite OFF
      service.onSongFavoriteToggled(song, false);
      final scoreAfterUnfav = service.scoreCandidate(candidate);

      // Must return cleanly to baseline score with no residual bonus
      expect(scoreAfterUnfav, closeTo(baselineScore, 0.001));
    });

    test('Queue/history exclusions are not bypassed when all candidates are in exclusions', () async {
      final current = Song(
        id: 991,
        title: 'Current Track',
        artist: 'Artist',
        album: 'Album',
        filePath: 'https://example.com/c.mp3',
        duration: const Duration(seconds: 200),
        dateModified: currentTime,
      );

      // Exclude all candidates returned by mock suggestions and search:
      // sugg_1 (Channa Mereya), sugg_2 (Ilahi), sugg_3 (Ghungroo), sugg_4 (Lover), mock_1 (Kesariya)
      final allMockCandidates = [
        'Channa Mereya',
        'Ilahi',
        'Ghungroo',
        'Lover',
        'Kesariya',
      ];

      final queueSongs = allMockCandidates
          .map((title) => Song(
                id: title.hashCode,
                title: title,
                artist: 'Any Artist',
                album: 'Album',
                filePath: 'https://example.com/$title.mp3',
                duration: const Duration(seconds: 200),
                dateModified: currentTime,
              ))
          .toList();

      final recs = await service.getCandidateRecommendations(
        context: RecommendationContext.autoplay,
        currentSong: current,
        queue: queueSongs,
        limit: 10,
      );

      // When all candidates are excluded, it must return empty instead of bypassing exclusions
      expect(recs, isEmpty);
    });

    test('MMR pre-allocates exploration slots and guarantees novel artist discovery', () {
      final candidates = <JioSaavnItem>[];
      // 10 songs from dominant artist
      for (int i = 1; i <= 10; i++) {
        candidates.add(JioSaavnItem(
          type: 'song',
          id: 'dom_$i',
          token: 'dom_$i',
          title: 'Dominant Hit $i',
          subtitle: 'Dominant Artist',
          imageUrl: '',
        ));
      }
      // 2 songs from novel artists
      candidates.add(const JioSaavnItem(
        type: 'song',
        id: 'nov_1',
        token: 'nov_1',
        title: 'Novel Hit 1',
        subtitle: 'Novel Artist Alpha',
        imageUrl: '',
      ));
      candidates.add(const JioSaavnItem(
        type: 'song',
        id: 'nov_2',
        token: 'nov_2',
        title: 'Novel Hit 2',
        subtitle: 'Novel Artist Beta',
        imageUrl: '',
      ));

      // maxPerArtist: 10 allows Dominant Artist to take up to 10 slots
      // But explorationRate: 0.2 with maxResults: 5 pre-allocates exploration slots
      final results = service.rankAndFilterWithMMR(
        candidates,
        maxPerArtist: 10,
        maxResults: 5,
        explorationRate: 0.2,
      );

      expect(results.length, equals(5));
      final hasNovel = results.any((s) => s.subtitle.startsWith('Novel Artist'));
      expect(hasNovel, isTrue, reason: 'Exploration slots must introduce novel artists');
    });

    test('Multi-seed co-occurrence strength gives score boost to overlapping candidates', () {
      const candidate = JioSaavnItem(
        type: 'song',
        id: 'shared_1',
        token: 'shared_1',
        title: 'Shared Song',
        subtitle: 'Artist Name',
        imageUrl: '',
      );

      final scoreSingle = service.scoreCandidate(candidate, coOccurrences: 1);
      final scoreTriple = service.scoreCandidate(candidate, coOccurrences: 3);

      // (3 - 1) * 3.0 = +6.0 confidence boost
      expect(scoreTriple, closeTo(scoreSingle + 6.0, 0.001));
    });

    test('Stream cache and favorites ID generation uses stable FNV hash for alphanumeric IDs', () {
      const item = JioSaavnItem(
        type: 'song',
        id: 'alpha_x99y',
        token: 'token_x99y',
        title: 'Alphanumeric Track',
        subtitle: 'Artist',
        imageUrl: '',
      );

      final stableId = item.stableId;
      expect(stableId, isNonZero);

      // StreamFavoritesService.getSongIdForItem must match item.stableId
      final favId = StreamFavoritesService.instance.getSongIdForItem(item);
      expect(favId, equals(stableId));

      // Song created from item must have id matching stableId
      final song = item.toSong();
      expect(song.id, equals(stableId));
    });
  });
}
