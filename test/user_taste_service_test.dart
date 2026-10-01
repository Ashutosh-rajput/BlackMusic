import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl/data/models/jiosaavn_item.dart';
import 'package:vinyl/data/models/song_model.dart';
import 'package:vinyl/services/stream_favorites_service.dart';
import 'package:vinyl/services/user_taste_service.dart';

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

    test('Search-and-played songs are given highest priority in scoring and recommendations', () async {
      // 1. Create a regular played song
      final regularSong = Song(
        id: 101,
        title: 'Passive Song',
        artist: 'Passive Artist',
        album: 'JioSaavn',
        filePath: 'stream://101',
        duration: const Duration(seconds: 200),
        dateModified: currentTime,
      );
      service.onSongStarted(regularSong);

      // 2. Create a search-and-played song
      const searchItem = JioSaavnItem(
        type: 'song',
        id: 'search_99',
        token: 'token_search_99',
        title: 'Searched Masterpiece',
        subtitle: 'Special Artist',
        imageUrl: 'https://example.com/art.jpg',
        duration: '240',
        language: 'hindi',
      );
      final searchSong = searchItem.toSong();
      service.recordSearchPlay(searchSong, item: searchItem);

      // Verify interaction
      final searchInteractions = service.getSearchPlayedInteractions();
      expect(searchInteractions.length, equals(1));
      expect(searchInteractions.first.searchPlayCount, equals(1));
      expect(searchInteractions.first.title, equals('Searched Masterpiece'));
      expect(searchInteractions.first.imageUrl, equals('https://example.com/art.jpg'));

      // 3. Compare candidate scores: search song vs regular song
      const regularItem = JioSaavnItem(
        type: 'song',
        id: '101',
        token: '101',
        title: 'Passive Song',
        subtitle: 'Passive Artist',
        imageUrl: '',
      );

      final searchScore = service.scoreCandidate(searchItem);
      final regularScore = service.scoreCandidate(regularItem);

      // Search score should have the massive priority bonus (>= 30.0) compared to passive song (< 10.0)
      expect(searchScore, greaterThan(30.0));
      expect(regularScore, lessThan(10.0));
      expect(searchScore, greaterThan(regularScore + 20.0),
          reason: 'Search-played song must receive decisively higher score');

      // 4. Recommendations from the searched artist should also get an affinity boost
      const relatedCandidate = JioSaavnItem(
        type: 'song',
        id: 'related_1',
        token: 'related_1',
        title: 'Another Hit',
        subtitle: 'Special Artist',
        imageUrl: '',
      );
      const unrelatedCandidate = JioSaavnItem(
        type: 'song',
        id: 'unrelated_1',
        token: 'unrelated_1',
        title: 'Unrelated Song',
        subtitle: 'Unknown Singer',
        imageUrl: '',
      );
      final relatedScore = service.scoreCandidate(relatedCandidate);
      final unrelatedScore = service.scoreCandidate(unrelatedCandidate);
      expect(relatedScore, greaterThan(unrelatedScore + 4.0),
          reason: 'Candidate from searched artist must receive affinity boost');

      // 5. In home recommendations, the search-played song must be exempt from history exclusion
      // and rank at the top (#1)
      final recommendations = await service.getCandidateRecommendations(
        context: RecommendationContext.home,
        recentHistory: [searchSong, regularSong],
        lang: 'hindi',
        limit: 10,
      );

      expect(recommendations.isNotEmpty, isTrue);
      expect(recommendations.first.canonicalKey, equals(searchItem.canonicalKey),
          reason: 'Search-played song must have highest priority (#1) in suggestions');
    });

    test('Search play count and metadata persist and reload across restarts', () async {
      const searchItem = JioSaavnItem(
        type: 'song',
        id: 'persist_search_1',
        token: 'token_persist_1',
        title: 'Persistent Search Hit',
        subtitle: 'Star Artist',
        imageUrl: 'https://example.com/cover.jpg',
        duration: '195',
        language: 'hindi',
      );
      final song = searchItem.toSong();
      service.recordSearchPlay(song, item: searchItem);

      // Flush to disk
      await service.flush();
      expect(tempFile.existsSync(), isTrue);

      // Reload into fresh service instance
      final freshService = UserTasteService(
        clock: () => currentTime,
        storageFile: tempFile,
      );
      await freshService.init();

      final reloaded = freshService.getSearchPlayedInteractions();
      expect(reloaded.length, equals(1));
      expect(reloaded.first.title, equals('Persistent Search Hit'));
      expect(reloaded.first.searchPlayCount, equals(1));
      expect(reloaded.first.imageUrl, equals('https://example.com/cover.jpg'));

      final score = freshService.scoreCandidate(searchItem);
      expect(score, greaterThan(30.0));
      freshService.dispose();
    });

    test('Taste Profile Editing: removeTrackedSong, removeTrackedArtist, addPreferredArtist, and clearTasteProfile', () async {
      await service.init();

      final song1 = Song(
        id: 301,
        title: 'Song One',
        artist: 'Special Artist',
        album: 'Album',
        filePath: 'mock/path1',
        duration: const Duration(seconds: 200),
        dateModified: DateTime.now(),
      );
      final song2 = Song(
        id: 302,
        title: 'Song Two',
        artist: 'Other Artist',
        album: 'Album',
        filePath: 'mock/path2',
        duration: const Duration(seconds: 200),
        dateModified: DateTime.now(),
      );

      service.onSongStarted(song1);
      service.onPlaybackProgress(song1, const Duration(seconds: 190), song1.duration);
      service.onSongStarted(song2);
      service.onPlaybackProgress(song2, const Duration(seconds: 190), song2.duration);

      expect(service.trackedSongCount, equals(2));
      expect(service.trackedArtistCount, equals(2));

      // Test removeTrackedSong
      final removed = await service.removeTrackedSong(song1.canonicalKey);
      expect(removed, isTrue);
      expect(service.trackedSongCount, equals(1));
      expect(service.getTrackedSongs().any((s) => s.title == 'Song One'), isFalse);

      // Test addPreferredArtist
      await service.addPreferredArtist('Legendary Singer');
      expect(service.isSearchPlayedArtist('legendary singer'), isTrue);
      final topArtists = service.getTrackedArtists();
      expect(topArtists.any((a) => a.key == 'legendary singer'), isTrue);

      // Test removeTrackedArtist
      final pruned = await service.removeTrackedArtist('Other Artist');
      expect(pruned, greaterThanOrEqualTo(1));
      expect(service.getTrackedArtists().any((a) => a.key == 'other artist'), isFalse);

      // Test clearTasteProfile
      await service.clearTasteProfile();
      expect(service.trackedSongCount, equals(0));
      expect(service.trackedArtistCount, equals(0));
    });

    test('Preferred artist boosts the artist but never appears as a song', () async {
      await service.init();
      await service.addPreferredArtist('Arijit Singh');

      // Not a song: not counted, not listed, not a searched song.
      expect(service.trackedSongCount, equals(0));
      expect(service.getTrackedSongs(), isEmpty);
      expect(service.getSearchPlayedInteractions(), isEmpty);

      // Still boosts the artist.
      expect(service.isSearchPlayedArtist('arijit singh'), isTrue);
      expect(service.getTopArtists(), contains('arijit singh'));

      // And never leaks into Home recommendations as a fake track.
      final recs = await service.getCandidateRecommendations(context: RecommendationContext.home);
      expect(recs.any((r) => r.title == 'Top Artist Selection' || r.id == '0'), isFalse);
    });

    group('Off-topic content guard', () {
      JioSaavnItem item(String id, String title, String artist) => JioSaavnItem(
            type: 'song',
            id: id,
            token: id,
            title: title,
            subtitle: artist,
            imageUrl: '',
            duration: '240',
            language: 'hindi',
          );

      final mixedPool = [
        item('b1', 'Channa Mereya', 'Arijit Singh'),
        item('b2', 'Tum Se Hi', 'Mohit Chauhan'),
        item('d1', 'Om Jai Jagdish Hare Aarti', 'Anuradha Paudwal'),
        item('k1', 'Motu Patlu Title Song', 'Nickelodeon Kids'),
        item('b3', 'Kabira', 'Tochi Raina, Rekha Bhardwaj'),
      ];

      UserTasteService serviceWithPool() => UserTasteService(
            clock: () => currentTime,
            storageFile: tempFile,
            searchSongs: (q) async => const [],
            fetchSuggestions: (id, {limit = 10}) async => mixedPool,
          );

      final bollywoodSeed = Song(
        id: 1001,
        mediaId: 'seed_1',
        title: 'Kesariya',
        artist: 'Arijit Singh',
        album: 'Brahmastra',
        filePath: 'https://example.com/kesariya.mp4',
        duration: const Duration(seconds: 268),
        dateModified: DateTime(2026, 1, 1),
        source: 'jiosaavn',
      );

      test('classifier recognises devotional and kids tracks, not film songs', () {
        expect(ContentClassifier.classify('Om Jai Jagdish Hare Aarti'), ContentCategory.devotional);
        expect(ContentClassifier.classify('Hanuman Chalisa'), ContentCategory.devotional);
        expect(ContentClassifier.classify('Motu Patlu Title Song'), ContentCategory.kids);
        expect(ContentClassifier.classify('Johny Johny Yes Papa Nursery Rhymes'), ContentCategory.kids);
        expect(ContentClassifier.classify('Channa Mereya Arijit Singh'), isNull);
        expect(ContentClassifier.classify('Kesariya Brahmastra'), isNull);
      });

      test('Bollywood autoplay never adds an aarti or a cartoon theme', () async {
        final svc = serviceWithPool();
        final recs = await svc.getCandidateRecommendations(
          context: RecommendationContext.autoplay,
          currentSong: bollywoodSeed,
        );
        final ids = recs.map((r) => r.id).toSet();
        expect(ids, containsAll(['b1', 'b2', 'b3']));
        expect(ids.contains('d1'), isFalse);
        expect(ids.contains('k1'), isFalse);
      });

      test('devotional autoplay still gets devotional tracks', () async {
        final svc = serviceWithPool();
        final aartiSeed = bollywoodSeed.copyWith(
          id: 1002,
          mediaId: 'seed_2',
          title: 'Hanuman Chalisa',
          artist: 'Hariharan',
          album: 'Shree Hanuman Chalisa',
        );
        final recs = await svc.getCandidateRecommendations(
          context: RecommendationContext.autoplay,
          currentSong: aartiSeed,
        );
        expect(recs.map((r) => r.id), contains('d1'));
        expect(recs.map((r) => r.id).contains('k1'), isFalse);
      });

      test('a kids track the user searched for is allowed in recommendations', () async {
        final svc = serviceWithPool();
        svc.recordSearchPlay(Song(
          id: 1003,
          title: 'Chhota Bheem Title Track',
          artist: 'Kids Channel',
          album: 'Chhota Bheem',
          filePath: '',
          duration: const Duration(seconds: 120),
          dateModified: DateTime(2026, 1, 1),
          source: 'jiosaavn',
        ));
        final recs = await svc.getCandidateRecommendations(
          context: RecommendationContext.autoplay,
          currentSong: bollywoodSeed,
        );
        expect(recs.map((r) => r.id), contains('k1'));
        expect(recs.map((r) => r.id).contains('d1'), isFalse);
      });
    });

    test('the same song listed several times is suggested only once', () async {
      JioSaavnItem listing(String id, String title, String artist, String dur) => JioSaavnItem(
            type: 'song',
            id: id,
            token: id,
            title: title,
            subtitle: artist,
            imageUrl: '',
            duration: dur,
            language: 'hindi',
          );

      final svc = UserTasteService(
        clock: () => currentTime,
        storageFile: tempFile,
        searchSongs: (q) async => const [],
        fetchSuggestions: (id, {limit = 10}) async => [
          listing('k1', 'Kesariya', 'Arijit Singh', '268'),
          listing('k2', 'Kesariya (From "Brahmastra")', 'Arijit Singh, Pritam', '268'),
          listing('k3', 'Kesariya', 'Pritam', '267'),
          listing('o1', 'Kesariya', 'Sid Sriram', '240'), // a different song, same name
          listing('c1', 'Channa Mereya', 'Arijit Singh', '289'),
          listing('c2', 'Channa Mereya', 'Arijit Singh, Pritam', '289'),
        ],
      );

      final seed = Song(
        id: 77,
        mediaId: 'seed77',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        filePath: 'https://example.com/x.mp4',
        duration: const Duration(seconds: 262),
        dateModified: DateTime(2026, 1, 1),
        source: 'jiosaavn',
      );
      final recs = await svc.getCandidateRecommendations(
        context: RecommendationContext.autoplay,
        currentSong: seed,
        limit: 10,
      );

      final kesariya = recs.where((r) => r.title.startsWith('Kesariya')).toList();
      final channa = recs.where((r) => r.title == 'Channa Mereya').toList();
      // k1 + k2 + k3 are one song; o1 (other artist, other length) is another.
      expect(kesariya, hasLength(2));
      expect(kesariya.map((r) => r.id), contains('o1'));
      expect(channa, hasLength(1));
    });

    test('findBestSeedMatch never picks a same-titled song by a different artist', () {
      final seed = Song(
        id: 910,
        title: 'Kesariya',
        artist: 'Arijit Singh',
        album: 'Brahmastra',
        filePath: '/music/kesariya.mp3',
        duration: const Duration(seconds: 268),
        dateModified: DateTime.now(),
      );
      JioSaavnItem cand(String id, String title, String artist, String lang, String dur) => JioSaavnItem(
            type: 'song',
            id: id,
            token: id,
            title: title,
            subtitle: artist,
            imageUrl: '',
            duration: dur,
            language: lang,
          );

      // Only the Tamil version by other singers is in the search results.
      final onlyOtherVersion = [cand('t1', 'Kesariya', 'Sid Sriram, Pritam', 'tamil', '262')];
      expect(UserTasteService.findBestSeedMatch(seed, onlyOtherVersion), isNull);

      // When the real song is there too, it wins over the same-titled one.
      final both = [
        cand('t1', 'Kesariya', 'Sid Sriram, Pritam', 'tamil', '262'),
        cand('h1', 'Kesariya', 'Arijit Singh, Pritam', 'hindi', '268'),
      ];
      expect(UserTasteService.findBestSeedMatch(seed, both)?.id, equals('h1'));
    });

    test('findBestSeedMatch returns null instead of an unrelated first result', () {
      final seed = Song(
        id: 900,
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        filePath: '/music/tum_hi_ho.mp3',
        duration: const Duration(seconds: 262),
        dateModified: DateTime.now(),
      );
      final unrelated = [
        JioSaavnItem(
          type: 'album',
          id: 'alb_1',
          token: 'alb_1',
          title: 'Some Album',
          subtitle: 'Various',
          imageUrl: '',
        ),
        JioSaavnItem(
          type: 'song',
          id: 'x_1',
          token: 'x_1',
          title: 'Completely Different Track',
          subtitle: 'Other Band',
          imageUrl: '',
          duration: '100',
        ),
      ];
      expect(UserTasteService.findBestSeedMatch(seed, unrelated), isNull);
    });
  
    group('Radio widens the pool with other songs by each credited artist', () {
      JioSaavnItem item(String id, String title, String artist) => JioSaavnItem(
            type: 'song', id: id, token: id, title: title, subtitle: artist, imageUrl: '',
            duration: '200', language: 'hindi', directMediaUrl: 'https://x/$id.mp3');

      Song seed() => Song(
            id: 1, mediaId: 'seed1', title: 'Boom Shaka', artist: 'Dhanda Nyoliwala, KR\$NA',
            album: 'Boom Shaka', filePath: 'https://x/seed.mp4', duration: const Duration(seconds: 218),
            dateModified: DateTime(2026), source: 'jiosaavn');

      UserTasteService build({required List<String> calls}) => UserTasteService(
            storageFile: tempFile,
            searchSongs: (q) async => const [],
            // reco.getreco: ten songs, nearly all by one artist
            fetchSuggestions: (id, {limit = 15}) async {
              calls.add('reco:$id');
              return [for (var i = 0; i < 10; i++) item('r$i', 'Reco Song $i', 'Dhanda Nyoliwala')];
            },
            fetchSongArtists: (id) async {
              calls.add('artists:$id');
              return [(id: 'a1', name: 'Dhanda Nyoliwala'), (id: 'a2', name: 'KR\$NA')];
            },
            fetchArtistSongs: (artistId, songId, {lang = ''}) async {
              calls.add('other:$artistId:$songId');
              return [for (var i = 0; i < 4; i++) item('$artistId-$i', '$artistId Song $i', artistId == 'a2' ? 'KR\$NA' : 'Dhanda Nyoliwala')];
            },
          );

      test('radio calls reco, then the other-songs call once per credited artist, and combines them', () async {
        final calls = <String>[];
        final svc = build(calls: calls);
        final recs = await svc.getCandidateRecommendations(
            context: RecommendationContext.radio, currentSong: seed(), limit: 25);
        expect(calls.where((c) => c.startsWith('reco:')), ['reco:seed1']);
        expect(calls.where((c) => c.startsWith('other:')).toSet(), {'other:a1:seed1', 'other:a2:seed1'});
        // KR$NA's own songs are now in the result, and so is the reco list.
        expect(recs.any((r) => r.subtitle == 'KR\$NA'), isTrue);
        expect(recs.any((r) => r.title.startsWith('Reco Song')), isTrue);
        // the artist cap no longer cuts a widened pool down to a handful
        expect(recs.length, greaterThan(6));
      });

      test('autoplay does NOT make the extra artist calls', () async {
        final calls = <String>[];
        final svc = build(calls: calls);
        await svc.getCandidateRecommendations(
            context: RecommendationContext.autoplay, currentSong: seed(), limit: 15);
        expect(calls.where((c) => c.startsWith('other:') || c.startsWith('artists:')), isEmpty);
      });

      test('one failing artist lookup does not lose the rest', () async {
        final svc = UserTasteService(
          storageFile: tempFile,
          searchSongs: (q) async => const [],
          fetchSuggestions: (id, {limit = 15}) async => [item('r0', 'Reco Song', 'Dhanda Nyoliwala')],
          fetchSongArtists: (id) async => [(id: 'a1', name: 'A'), (id: 'a2', name: 'B')],
          fetchArtistSongs: (artistId, songId, {lang = ''}) async {
            if (artistId == 'a1') throw Exception('boom');
            return [item('b-0', 'B Song', 'KR\$NA')];
          },
        );
        final recs = await svc.getCandidateRecommendations(
            context: RecommendationContext.radio, currentSong: seed(), limit: 10);
        expect(recs.any((r) => r.title == 'B Song'), isTrue);
        expect(recs.any((r) => r.title == 'Reco Song'), isTrue);
      });
    });

    group('Autoplay artist cap adapts to the suggestion list', () {
      JioSaavnItem item(String id, String title, String artist) => JioSaavnItem(
            type: 'song', id: id, token: id, title: title, subtitle: artist, imageUrl: '',
            duration: '200', language: 'hindi', directMediaUrl: 'https://x/$id.mp3');

      Song seed() => Song(
            id: 1, mediaId: 'seed1', title: 'Seed Song', artist: 'Someone Else',
            album: 'A', filePath: 'https://x/seed.mp4', duration: const Duration(seconds: 200),
            dateModified: DateTime(2026), source: 'jiosaavn');

      test('a list that is nearly all one artist still fills the queue (was cut to 3)', () async {
        final svc = UserTasteService(
          storageFile: tempFile,
          searchSongs: (q) async => const [],
          fetchSuggestions: (id, {limit = 15}) async => [
            for (var i = 0; i < 19; i++) item('d$i', 'Dhanda Song $i', 'Dhanda Nyoliwala'),
            item('o1', 'Other Song', 'Music bm'),
          ],
        );
        final recs = await svc.getCandidateRecommendations(
            context: RecommendationContext.autoplay, currentSong: seed(), limit: 15);
        expect(recs.length, greaterThanOrEqualTo(12));
      });

      test('a varied list keeps the cap of 2 per artist', () async {
        final svc = UserTasteService(
          storageFile: tempFile,
          searchSongs: (q) async => const [],
          fetchSuggestions: (id, {limit = 15}) async => [
            for (var a = 0; a < 8; a++)
              for (var i = 0; i < 3; i++) item('a$a-$i', 'Song $a-$i', 'Artist $a'),
          ],
        );
        final recs = await svc.getCandidateRecommendations(
            context: RecommendationContext.autoplay, currentSong: seed(), limit: 15);
        final perArtist = <String, int>{};
        for (final r in recs) {
          perArtist[r.subtitle] = (perArtist[r.subtitle] ?? 0) + 1;
        }
        expect(perArtist.values.every((n) => n <= 2), isTrue);
      });
    });
});
}
