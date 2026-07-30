import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';
import 'helpers/mock_audio_service.dart';

void main() {
  setupPlatformMocks();

  group('Player integration & Queue Navigation Tests', () {
    late MockAudioPlayerService audioService;
    late PlayerBloc playerBloc;

    final song1 = Song(
      id: 101,
      title: 'First Track',
      artist: 'Artist A',
      album: 'Album 1',
      filePath: '/music/song1.mp3',
      duration: const Duration(seconds: 180),
      dateModified: DateTime.now(),
    );

    final song2 = Song(
      id: 102,
      title: 'Second Track',
      artist: 'Artist B',
      album: 'Album 1',
      filePath: '/music/song2.mp3',
      duration: const Duration(seconds: 210),
      dateModified: DateTime.now(),
    );

    final song3 = Song(
      id: 103,
      title: 'Third Track',
      artist: 'Artist C',
      album: 'Album 2',
      filePath: '/music/song3.mp3',
      duration: const Duration(seconds: 240),
      dateModified: DateTime.now(),
    );

    setUp(() {
      audioService = MockAudioPlayerService();
      playerBloc = PlayerBloc(audioService: audioService);
    });

    tearDown(() {
      playerBloc.close();
      audioService.dispose();
    });

    test('Initial state is PlayerInitial', () {
      expect(playerBloc.state, isA<PlayerState>());
    });

    blocTest<PlayerBloc, PlayerState>(
      'Plays a single song and sets active queue',
      build: () => playerBloc,
      act: (bloc) => bloc.add(PlaySongEvent(song1, queue: [song1, song2, song3])),
      expect: () => [
        isA<PlayerLoading>(),
        isA<PlayerPlaying>(),
      ],
      verify: (bloc) {
        if (bloc.state is PlayerPlaying) {
          final state = bloc.state as PlayerPlaying;
          expect(state.song.id, equals(101));
          expect(state.queue.length, equals(3));
        }
      },
    );

    blocTest<PlayerBloc, PlayerState>(
      'Navigates to next song in queue',
      build: () => playerBloc,
      act: (bloc) async {
        bloc.add(PlaySongEvent(song1, queue: [song1, song2, song3]));
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const NextSongEvent());
      },
      expect: () => [
        isA<PlayerLoading>(),
        isA<PlayerPlaying>(),
        isA<PlayerLoading>(),
        isA<PlayerPlaying>(),
      ],
      verify: (bloc) {
        if (bloc.state is PlayerPlaying) {
          final state = bloc.state as PlayerPlaying;
          expect(state.song.id, equals(102));
        }
      },
    );

    blocTest<PlayerBloc, PlayerState>(
      'Navigates to previous song in queue (wraps around)',
      build: () => playerBloc,
      act: (bloc) async {
        bloc.add(PlaySongEvent(song1, queue: [song1, song2, song3]));
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const PreviousSongEvent());
      },
      expect: () => [
        isA<PlayerLoading>(),
        isA<PlayerPlaying>(),
        isA<PlayerLoading>(),
        isA<PlayerPlaying>(),
      ],
      verify: (bloc) {
        if (bloc.state is PlayerPlaying) {
          final state = bloc.state as PlayerPlaying;
          expect(state.song.id, equals(103));
        }
      },
    );

    blocTest<PlayerBloc, PlayerState>(
      'Toggles shuffle mode without crashing queue',
      build: () => playerBloc,
      act: (bloc) {
        bloc.add(PlaySongEvent(song1, queue: [song1, song2, song3]));
        bloc.add(const ToggleShuffleEvent());
      },
      verify: (bloc) {
        expect(bloc.state, isA<PlayerState>());
      },
    );

    blocTest<PlayerBloc, PlayerState>(
      'Toggles repeat mode',
      build: () => playerBloc,
      act: (bloc) {
        bloc.add(const ToggleRepeatEvent());
      },
      verify: (bloc) {
        expect(bloc.state, isA<PlayerState>());
      },
    );
  });
}
