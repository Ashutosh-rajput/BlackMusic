import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vinyl/data/models/song_model.dart';
import 'package:vinyl/data/repositories/music_repository.dart';
import 'package:vinyl/presentation/bloc/library/library_bloc.dart';
import 'package:vinyl/presentation/bloc/library/library_state.dart';
import 'package:vinyl/presentation/bloc/player/player_bloc.dart';
import 'package:vinyl/presentation/bloc/player/player_event.dart';
import 'package:vinyl/presentation/bloc/player/player_state.dart';
import 'package:vinyl/presentation/screens/player_screen.dart';
import 'package:vinyl/presentation/widgets/album_art_widget.dart';
import 'package:vinyl/presentation/widgets/wavy_slider.dart';
import 'package:vinyl/services/audio_service.dart';
import 'package:vinyl/services/file_service.dart';
import 'package:vinyl/services/settings_service.dart';
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

    tearDown(() async {
      await playerBloc.close();
      await libraryBloc.close();
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
        // 1. Build the PlayerScreen and start playback
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

        await tester.runAsync(() async {
          playerBloc.add(PlaySongEvent(testSong, queue: [testSong]));
          await Future.delayed(const Duration(milliseconds: 150));
        });

        await tester.pump();

        // Confirm playing state is active: pause icon should be visible
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Verify Slider has WavySliderTrackShape with isPlaying == true
        final sliderFinder = find.byType(Slider);
        expect(sliderFinder, findsOneWidget);
        SliderTheme sliderTheme = tester.widget<SliderTheme>(
          find.ancestor(of: sliderFinder, matching: find.byType(SliderTheme)),
        );
        // The wave eases in: after the animation settles it is at full height.
        await tester.pump(const Duration(milliseconds: 600));
        sliderTheme = tester.widget<SliderTheme>(
          find.ancestor(of: sliderFinder, matching: find.byType(SliderTheme)),
        );
        final activeTrack = sliderTheme.data.trackShape as WavySliderTrackShape;
        expect(sliderTheme.data.thumbShape, isA<WavyHandleSliderThumbShape>());
        expect(activeTrack.isPlaying, isTrue);
        expect(activeTrack.amplitude, closeTo(1.0, 0.01));

        // 2. Simulate user pausing from notification panel / bluetooth
        await tester.runAsync(() async {
          await audioService.pause();
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        // 3. Verify ALL playback animations stop and play icon is shown:
        // - Play icon is shown (NOT pause icon)
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.pause_rounded), findsNothing);
        // - CircularProgressIndicator is NOT shown
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // - The wave flattens to a straight line (eases out, then amplitude 0)
        await tester.pump(const Duration(milliseconds: 600));
        sliderTheme = tester.widget<SliderTheme>(
          find.ancestor(of: sliderFinder, matching: find.byType(SliderTheme)),
        );
        final pausedTrack = sliderTheme.data.trackShape as WavySliderTrackShape;
        expect(pausedTrack.isPlaying, isFalse);
        expect(pausedTrack.amplitude, closeTo(0.0, 0.01));

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
      },
    );
  
    group('Swiping the disc changes song', () {
      Song song(int id) => Song(
            id: id, title: 'Track $id', artist: 'Artist', album: 'Album',
            filePath: '/music/t$id.mp3', duration: const Duration(seconds: 200),
            dateModified: DateTime.now());

      Future<void> openPlayerOnSecondSong(WidgetTester tester) async {
        final queue = [song(1), song(2), song(3)];
        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<PlayerBloc>.value(value: playerBloc),
                BlocProvider<LibraryBloc>.value(value: libraryBloc),
              ],
              child: PlayerScreen(song: queue[1]),
            ),
          ),
        );
        await tester.runAsync(() async {
          playerBloc.add(PlaySongEvent(queue[1], queue: queue));
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
      }

      Future<String?> titleAfterSwipe(WidgetTester tester, Offset by) async {
        await openPlayerOnSecondSong(tester);
        final disc = find.byType(AlbumArtWidget);
        expect(disc, findsOneWidget);
        await tester.drag(disc, by);
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 300));
        final state = playerBloc.state;
        return state is PlayerPlaying ? state.song.title : null;
      }

      testWidgets('swipe left plays the next song', (tester) async {
        expect(await titleAfterSwipe(tester, const Offset(-200, 0)), 'Track 3');
      });

      testWidgets('swipe right plays the previous song', (tester) async {
        expect(await titleAfterSwipe(tester, const Offset(200, 0)), 'Track 1');
      });

      testWidgets('a tiny drag does nothing and the disc springs back', (tester) async {
        expect(await titleAfterSwipe(tester, const Offset(-20, 0)), 'Track 2');
      });
    });
});
}
