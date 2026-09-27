import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_player/data/models/jiosaavn_item.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';
import 'package:pixel_player/services/user_taste_service.dart';
import 'helpers/mock_audio_service.dart';

void main() {
  setupPlatformMocks();

  group('Infinite Playback Queue Auto-Expansion Tests', () {
    late MockAudioPlayerService audioService;
    late PlayerBloc playerBloc;

    Song createSong(int id, String title, {String artist = 'Artist'}) {
      return Song(
        id: id,
        title: title,
        artist: artist,
        album: 'Album',
        filePath: 'https://example.com/stream_$id.mp3',
        duration: const Duration(minutes: 3),
        dateModified: DateTime.now(),
        source: 'jiosaavn',
      );
    }

    JioSaavnItem createItem(String id, String title, {String artist = 'Artist'}) {
      return JioSaavnItem(
        type: 'song',
        id: id,
        token: id,
        title: title,
        subtitle: artist,
        imageUrl: 'https://example.com/art.jpg',
        directMediaUrl: 'https://example.com/$id.mp3',
        duration: '180',
      );
    }

    setUp(() {
      audioService = MockAudioPlayerService();

      // Configure UserTasteService mock functions
      UserTasteService(
        clock: () => DateTime.now(),
        searchSongs: (q) async => [
          createItem('seed_1', 'Target Seed', artist: 'Seed Artist'),
        ],
        fetchSuggestions: (id, {limit = 10}) async => [
          createItem('sug_101', 'Infinite Track 1', artist: 'Discovery 1'),
          createItem('sug_102', 'Infinite Track 2', artist: 'Discovery 2'),
          createItem('sug_103', 'Infinite Track 3', artist: 'Discovery 3'),
          createItem('sug_104', 'Infinite Track 4', artist: 'Discovery 4'),
        ],
      );

      playerBloc = PlayerBloc(audioService: audioService);
    });

    tearDown(() {
      playerBloc.close();
    });

    test('Queue does not expand when remaining songs > 3', () async {
      // 10 songs in queue, playing song 0 -> remaining = 9 > 3
      final initialQueue = List.generate(10, (i) => createSong(i + 1, 'Song ${i + 1}'));
      playerBloc.add(PlayQueueEvent(initialQueue, initialIndex: 0));

      await expectLater(
        playerBloc.stream,
        emitsThrough(predicate<PlayerState>((s) => s is PlayerPlaying && s.song.id == 1)),
      );

      // Wait brief moment for any async events
      await Future.delayed(const Duration(milliseconds: 150));

      final state = playerBloc.state;
      expect(state, isA<PlayerPlaying>());
      final playing = state as PlayerPlaying;
      expect(playing.queue.length, equals(10));
    });

    test('Queue automatically expands when remaining songs <= 3', () async {
      // 5 songs in queue, playing index 2 (Song 3) -> remaining = 5 - 1 - 2 = 2 <= 3
      final initialQueue = List.generate(5, (i) => createSong(i + 1, 'Song ${i + 1}'));
      playerBloc.add(PlayQueueEvent(initialQueue, initialIndex: 2));

      await expectLater(
        playerBloc.stream,
        emitsThrough(predicate<PlayerState>((s) => s is PlayerPlaying && s.queue.length > 5)),
      );

      final state = playerBloc.state as PlayerPlaying;
      expect(state.queue.length, greaterThan(5));
      // First 5 songs preserved in exact order
      for (int i = 0; i < 5; i++) {
        expect(state.queue[i].id, equals(initialQueue[i].id));
      }
      // Newly fetched songs appended to the end
      expect(state.queue.any((s) => s.title == 'Infinite Track 1'), isTrue);
      expect(state.queue.any((s) => s.title == 'Infinite Track 2'), isTrue);
    });

    test('NextSongEvent at end of queue fills queue and continues playback seamlessly', () async {
      final initialQueue = [
        createSong(1, 'Solo Track'),
      ];

      playerBloc.add(PlaySongEvent(initialQueue.first, queue: initialQueue));

      await expectLater(
        playerBloc.stream,
        emitsThrough(predicate<PlayerState>((s) => s is PlayerPlaying)),
      );

      // Trigger next song when at the very end
      playerBloc.add(const NextSongEvent());

      await expectLater(
        playerBloc.stream,
        emitsThrough(predicate<PlayerState>(
          (s) => s is PlayerPlaying && s.song.title.contains('Infinite Track'),
        )),
      );

      final state = playerBloc.state as PlayerPlaying;
      expect(state.song.title, equals('Infinite Track 1'));
      expect(state.queue.length, greaterThan(1));
    });

    test('Queue expansion excludes existing songs to prevent duplicates', () async {
      // Setup suggestions containing a duplicate of a song already in queue
      UserTasteService(
        clock: () => DateTime.now(),
        searchSongs: (q) async => [
          createItem('seed_x', 'Second Song', artist: 'Artist'),
        ],
        fetchSuggestions: (id, {limit = 10}) async => [
          createItem('dup', 'Existing Song', artist: 'Artist'), // Duplicate
          createItem('unique_1', 'Brand New Song', artist: 'New Artist'),
        ],
      );

      final initialQueue = [
        createSong(10, 'Existing Song', artist: 'Artist'),
        createSong(11, 'Second Song', artist: 'Artist'),
      ];

      playerBloc.add(PlayQueueEvent(initialQueue, initialIndex: 0));

      await expectLater(
        playerBloc.stream,
        emitsThrough(predicate<PlayerState>((s) => s is PlayerPlaying && s.queue.length > 2)),
      );

      final state = playerBloc.state as PlayerPlaying;
      // Should not contain duplicate
      final existingCount = state.queue.where((s) => s.title.toLowerCase() == 'existing song').length;
      expect(existingCount, equals(1));
      expect(state.queue.any((s) => s.title == 'Brand New Song'), isTrue);
    });

    test('Queue from stream list advances through jiosaavn tracks with empty initial filePath and expands at end', () async {
      // Simulate stream screen queue where first song has URL, and remaining songs have empty initial filePath
      final song1 = createSong(1, 'List Song 1').copyWith(filePath: 'https://example.com/1.mp3');
      final song2 = createSong(2, 'List Song 2').copyWith(filePath: '');
      final song3 = createSong(3, 'List Song 3').copyWith(filePath: '');

      playerBloc.add(PlaySongEvent(song1, queue: [song1, song2, song3]));

      await expectLater(
        playerBloc.stream,
        emitsThrough(predicate<PlayerState>((s) => s is PlayerPlaying && s.song.id == 1)),
      );

      // Advance to song2 (whose initial filePath was empty)
      playerBloc.add(const NextSongEvent());

      await expectLater(
        playerBloc.stream,
        emitsThrough(predicate<PlayerState>((s) => s is PlayerPlaying && s.song.id == 2)),
      );

      // Advance to song3
      playerBloc.add(const NextSongEvent());

      await expectLater(
        playerBloc.stream,
        emitsThrough(predicate<PlayerState>((s) => s is PlayerPlaying && s.song.id == 3)),
      );

      // Advance past end of queue -> must expand infinitely with new tracks!
      playerBloc.add(const NextSongEvent());

      await expectLater(
        playerBloc.stream,
        emitsThrough(predicate<PlayerState>(
          (s) => s is PlayerPlaying && s.song.title.contains('Infinite Track'),
        )),
      );

      final state = playerBloc.state as PlayerPlaying;
      expect(state.queue.length, greaterThan(3));
    });
  });
}
