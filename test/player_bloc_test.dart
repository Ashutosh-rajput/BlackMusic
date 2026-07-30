import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';
import 'helpers/mock_audio_service.dart';

void main() {
  setupPlatformMocks();

  group('PlayerBloc Unit Tests', () {
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

    setUp(() {
      final audioService = MockAudioPlayerService();
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
  });
}
