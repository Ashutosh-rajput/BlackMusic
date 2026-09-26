import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_player/data/models/jiosaavn_item.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/services/user_taste_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserTasteService service;

  setUp(() async {
    service = UserTasteService();
    await service.init();
  });

  group('PulseIQ UserTasteService Tests', () {
    test('SongInteraction computes decay score and penalties correctly', () {
      final now = DateTime.now();

      final positiveSong = SongInteraction(
        songId: 1,
        title: 'Loved Track',
        artist: 'Arijit Singh',
        playCount: 5,
        completeCount: 4,
        skipCount: 0,
        lastInteraction: now,
      );

      final skippedSong = SongInteraction(
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

    test('MMR Diversity Filter limits tracks per artist to avoid echo chambers', () {
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

      // Arijit Singh should have at most 2 tracks included
      final arijitCount = filtered.where((s) => s.subtitle.toLowerCase().contains('arijit singh')).length;
      expect(arijitCount, lessThanOrEqualTo(2));
      expect(filtered.any((s) => s.title == 'Track 4'), isTrue);
      expect(filtered.any((s) => s.title == 'Track 5'), isTrue);
    });

    test('Implicit signals: onSongStarted and onPlaybackProgress track completions', () {
      final song = Song(
        id: 12345,
        title: 'Test Masterpiece',
        artist: 'Sachin-Jigar',
        album: 'Test Album',
        filePath: 'https://example.com/test.mp3',
        duration: const Duration(seconds: 200),
        dateModified: DateTime.now(),
      );

      service.onSongStarted(song);
      // Progress past 80% (165s / 200s = 82.5%)
      service.onPlaybackProgress(song, const Duration(seconds: 165), song.duration);

      final candidate = JioSaavnItem(
        type: 'song',
        id: '12345',
        token: '12345',
        title: 'Test Masterpiece',
        subtitle: 'Sachin-Jigar',
        imageUrl: '',
      );

      final score = service.scoreCandidate(candidate);
      expect(score, greaterThan(1.0));
    });

    test('Implicit signals: onSongSkipped penalizes candidate score', () {
      final song = Song(
        id: 8888,
        title: 'Annoying Track',
        artist: 'Skipped Artist',
        album: 'Test Album',
        filePath: 'https://example.com/skipped.mp3',
        duration: const Duration(seconds: 200),
        dateModified: DateTime.now(),
      );

      service.onSongStarted(song);
      // User skips after 5 seconds
      service.onSongSkipped(song);

      final candidate = JioSaavnItem(
        type: 'song',
        id: '8888',
        token: '8888',
        title: 'Annoying Track',
        subtitle: 'Skipped Artist',
        imageUrl: '',
      );

      final score = service.scoreCandidate(candidate);
      // Score should be clamped/penalized
      expect(score, equals(0.1)); // Clamped minimum
    });

    test('Explicit signals: onSongFavoriteToggled boosts candidate score and artist affinity', () {
      final song = Song(
        id: 7777,
        title: 'Favorite Track',
        artist: 'Pritam',
        album: 'Favorite Album',
        filePath: 'https://example.com/fav.mp3',
        duration: const Duration(seconds: 220),
        dateModified: DateTime.now(),
      );

      service.onSongFavoriteToggled(song, true);

      final candidate = const JioSaavnItem(
        type: 'song',
        id: '7777',
        token: '7777',
        title: 'Favorite Track',
        subtitle: 'Pritam',
        imageUrl: '',
      );

      final score = service.scoreCandidate(candidate);
      // Base score (1.0) + affinity (~6.0) + favorite bonus (8.0) + artist affinity (>0)
      expect(score, greaterThan(14.0));

      final topArtists = service.getTopArtists();
      expect(topArtists, contains('Pritam'));

      // Toggling off removes the favorite bonus
      service.onSongFavoriteToggled(song, false);
      final scoreAfter = service.scoreCandidate(candidate);
      expect(scoreAfter, lessThan(score));
    });
  });
}
