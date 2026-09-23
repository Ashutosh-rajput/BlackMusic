import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';
import 'package:pixel_player/presentation/bloc/library/library_state.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';
import 'package:pixel_player/presentation/screens/player_screen.dart';
import 'package:pixel_player/services/audio_service.dart';
import 'package:pixel_player/services/file_service.dart';
import 'package:pixel_player/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/mock_audio_service.dart';

class FakeLibraryBloc extends Cubit<LibraryState> implements LibraryBloc {
  FakeLibraryBloc()
      : super(const LibraryLoaded(allSongs: [], displayedSongs: []));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMusicRepository implements MusicRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFileService implements FileService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setupPlatformMocks();

  group('PlayerScreen Animation & External Pause Integration Tests', () {
    late MockAudioPlayerService audioService;
    late PlayerBloc playerBloc;
    late FakeLibraryBloc libraryBloc;
    final getIt = GetIt.instance;

    final testSong = Song(
      id: 999,
      title: 'Test Melody',
      artist: 'Test Singer',
      album: 'Test Album',
      filePath: '/music/test_melody.mp3',
      duration: const Duration(seconds: 200),
      dateModified: DateTime.now(),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'show_player_waveform': true,
        'player_background_pattern': 0,
      });
      final prefs = await SharedPreferences.getInstance();

      audioService = MockAudioPlayerService();
      playerBloc = PlayerBloc(audioService: audioService);
      libraryBloc = FakeLibraryBloc();

      if (getIt.isRegistered<AudioPlayerService>()) {
        getIt.unregister<AudioPlayerService>();
      }
      getIt.registerSingleton<AudioPlayerService>(audioService);

      if (getIt.isRegistered<SettingsService>()) {
        getIt.unregister<SettingsService>();
      }
      getIt.registerSingleton<SettingsService>(
        SettingsService(
          prefs: prefs,
          repository: FakeMusicRepository(),
          fileService: FakeFileService(),
        ),
      );
    });

    tearDown(() {
      playerBloc.close();
      libraryBloc.close();
      audioService.dispose();
      if (getIt.isRegistered<AudioPlayerService>()) {
        getIt.unregister<AudioPlayerService>();
      }
      if (getIt.isRegistered<SettingsService>()) {
        getIt.unregister<SettingsService>();
      }
    });

    testWidgets(
      'Notification pause immediately stops seeker wave, snake head, and shows play button',
      (tester) async {
        // 1. Start playback of test song and wait until PlayerPlaying state is emitted
        playerBloc.add(PlaySongEvent(testSong, queue: [testSong]));
        await expectLater(
          playerBloc.stream,
          emitsThrough(isA<PlayerPlaying>()),
        );

        // 2. Build the PlayerScreen widget tree
        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<PlayerBloc>.value(value: playerBloc),
                BlocProvider<LibraryBloc>.value(value: libraryBloc),
              ],
              child: PlayerScreen(song: testSong),
            ),
          ),
        );
        await tester.pump();

        // Verify currently playing: pause icon should be visible
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Verify Slider has SineWaveSliderTrackShape with isPlaying == true
        final sliderFinder = find.byType(Slider);
        expect(sliderFinder, findsOneWidget);
        SliderTheme sliderTheme = tester.widget<SliderTheme>(
          find.ancestor(of: sliderFinder, matching: find.byType(SliderTheme)),
        );
        final activeTrack = sliderTheme.data.trackShape as SineWaveSliderTrackShape;
        final thumb = sliderTheme.data.thumbShape as SnakeHeadSliderThumbShape;
        expect(activeTrack.isPlaying, isTrue);
        expect(thumb.isPlaying, isTrue);

        // 3. Simulate user pausing from notification panel / bluetooth
        await audioService.pause();
        await tester.pump(const Duration(milliseconds: 50));

        // 4. Verify ALL playback animations stop and play icon is shown immediately:
        // - Play icon is shown (NOT pause icon)
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.pause_rounded), findsNothing);
        // - CircularProgressIndicator is NOT shown
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // - Seeker track and snake head isPlaying are false
        sliderTheme = tester.widget<SliderTheme>(
          find.ancestor(of: sliderFinder, matching: find.byType(SliderTheme)),
        );
        final pausedTrack = sliderTheme.data.trackShape as SineWaveSliderTrackShape;
        final pausedThumb = sliderTheme.data.thumbShape as SnakeHeadSliderThumbShape;
        expect(pausedTrack.isPlaying, isFalse);
        expect(pausedThumb.isPlaying, isFalse);

        // Clean unmount before tearDown
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}

