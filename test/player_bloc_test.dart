import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'helpers/mock_audio_service.dart';

void main() {
  setupPlatformMocks();

  group('PlayerBloc Unit Tests', () {
    late MockAudioPlayerService audioService;
    late PlayerBloc playerBloc;

    final testSong = Song(
      id: 1,
      title: 'Test Track',
      artist: 'Test Artist',
      album: 'Test Album',
      filePath: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      duration: const Duration(minutes: 3),
      dateModified: DateTime.now(),
    );

    final testSong2 = Song(
      id: 2,
      title: 'Second Track',
      artist: 'Test Artist 2',
      album: 'Test Album 2',
      filePath: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      duration: const Duration(minutes: 4),
      dateModified: DateTime.now(),
    );

    setUp(() {
      audioService = MockAudioPlayerService();
      playerBloc = PlayerBloc(audioService: audioService);
    });

    tearDown(() {
      playerBloc.close();
    });

    test('initial state is PlayerInitial', () {
      expect(playerBloc.state, equals(const PlayerInitial()));
    });

    blocTest<PlayerBloc, PlayerState>(
      ('emits [PlayerLoading, PlayerPlaying] when PlaySongEvent is added'),
      build: () => playerBloc,
      act: (bloc) => bloc.add(PlaySongEvent(testSong)),
      expect: () => [
        PlayerLoading(song: testSong, queue: [testSong]),
        PlayerPlaying(
          song: testSong,
          position: Duration.zero,
          duration: const Duration(minutes: 3),
          isShuffle: false,
          isRepeat: false,
          queue: [testSong],
        ),
      ],
    );

    blocTest<PlayerBloc, PlayerState>(
      ('toggles shuffle when ToggleShuffleEvent is added'),
      build: () => playerBloc,
      act: (bloc) => bloc.add(const ToggleShuffleEvent()),
      expect: () => [],
    );

    test('automatically advances to next song from queue when ProcessingState.completed is emitted', () async {
      playerBloc.add(PlaySongEvent(testSong, queue: [testSong, testSong2]));
      await expectLater(
        playerBloc.stream,
        emitsThrough(predicate<PlayerState>((s) => s is PlayerPlaying && s.song.id == testSong.id)),
      );

      // Emit completion from audio player
      audioService.emitPlayerState(ja.PlayerState(false, ja.ProcessingState.completed));

      await expectLater(
        playerBloc.stream,
        emitsThrough(predicate<PlayerState>((s) => s is PlayerPlaying && s.song.id == testSong2.id)),
      );
    });

    test('rapid play requests cancel superseded request and emit only the latest song', () async {
      final states = <PlayerState>[];
      final sub = playerBloc.stream.listen(states.add);

      playerBloc.add(PlaySongEvent(testSong));
      playerBloc.add(PlaySongEvent(testSong2));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(playerBloc.state, isA<PlayerPlaying>());
      final playing = playerBloc.state as PlayerPlaying;
      expect(playing.song.id, equals(testSong2.id));

      final playingStates = states.whereType<PlayerPlaying>().toList();
      expect(playingStates.last.song.id, equals(testSong2.id));
      await sub.cancel();
    });

    test('queues over 25 songs retain full queue without 25-song truncation', () async {
      final largeQueue = List.generate(
        35,
        (i) => Song(
          id: 100 + i,
          title: 'Track $i',
          artist: 'Artist',
          album: 'Album',
          filePath: '/music/track$i.mp3',
          duration: const Duration(minutes: 3),
          dateModified: DateTime.now(),
        ),
      );

      playerBloc.add(PlaySongEvent(largeQueue.first, queue: largeQueue));
      await expectLater(
        playerBloc.stream,
        emitsThrough(predicate<PlayerState>((s) => s is PlayerPlaying && s.queue.length == 35)),
      );

      final state = playerBloc.state as PlayerPlaying;
      expect(state.queue.length, equals(35));
      expect(state.queue[30].id, equals(130));
    });

    test('AddSongsToQueueEvent appends songs to queue', () async {
      final states = <PlayerState>[];
      final sub = playerBloc.stream.listen(states.add);

      playerBloc.add(PlaySongEvent(testSong, queue: [testSong]));
      await Future.delayed(const Duration(milliseconds: 50));

      final extraSongs = [
        Song(
          id: 501,
          title: 'Extra 1',
          artist: 'Artist',
          album: 'Album',
          filePath: 'https://stream.saavn.com/501.mp4',
          duration: const Duration(minutes: 3),
          dateModified: DateTime.now(),
          source: 'jiosaavn',
        ),
        Song(
          id: 502,
          title: 'Extra 2',
          artist: 'Artist',
          album: 'Album',
          filePath: 'https://stream.saavn.com/502.mp4',
          duration: const Duration(minutes: 3),
          dateModified: DateTime.now(),
          source: 'jiosaavn',
        ),
      ];

      playerBloc.add(AddSongsToQueueEvent(extraSongs));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(playerBloc.state, isA<PlayerPlaying>());
      final state = playerBloc.state as PlayerPlaying;
      expect(state.queue.length, equals(3));
      expect(state.queue[1].id, equals(501));
      expect(state.queue[2].id, equals(502));
      await sub.cancel();
    });

    test('playing a searched song sets queue to only that song without auto-filling', () async {
      final searchSong = Song(
        id: 999,
        title: 'Searched Hit',
        artist: 'Search Artist',
        album: 'Album',
        filePath: 'https://stream.saavn.com/999.mp4',
        duration: const Duration(minutes: 3),
        dateModified: DateTime.now(),
        source: 'jiosaavn',
      );

      playerBloc.add(PlaySongEvent(searchSong, queue: [searchSong]));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(playerBloc.state, isA<PlayerPlaying>());
      final state = playerBloc.state as PlayerPlaying;
      expect(state.queue.length, equals(1));
      expect(state.queue.first.id, equals(999));
    });

    test('PlayQueueEvent successfully switches playback when a song is already playing', () async {
      playerBloc.add(PlaySongEvent(testSong));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(playerBloc.state, isA<PlayerPlaying>());
      expect((playerBloc.state as PlayerPlaying).song.id, equals(testSong.id));

      final albumQueue = [testSong, testSong2];
      playerBloc.add(PlayQueueEvent(albumQueue, initialIndex: 1));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(playerBloc.state, isA<PlayerPlaying>());
      final state = playerBloc.state as PlayerPlaying;
      expect(state.song.id, equals(testSong2.id));
      expect(state.queue.length, equals(2));
    });
  });
}
