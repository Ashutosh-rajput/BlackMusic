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
        PlayerLoading(song: testSong),
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
  });
}
