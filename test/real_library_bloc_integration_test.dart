import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:pixel_player/data/database/app_database.dart' hide Song;
import 'package:pixel_player/data/datasources/local/music_local_datasource.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/services/file_service.dart';
import 'package:pixel_player/services/permission_service.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';
import 'package:pixel_player/presentation/bloc/library/library_event.dart';
import 'package:pixel_player/presentation/bloc/library/library_state.dart';

class MockFileService implements FileService {
  @override
  Future<List<Song>> scanMusicLibrary({
    List<String>? specificPaths,
    bool recursive = true,
    bool ignoreShortAudio = true,
    bool showHiddenFiles = false,
  }) async => [];
}

class MockPermissionService implements PermissionService {
  @override
  Future<bool> requestMusicPermission() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('REAL LibraryBloc & SQLite Database Integration Tests', () {
    late AppDatabase db;
    late MusicLocalDatasourceImpl localDatasource;
    late MusicRepositoryImpl repository;
    late LibraryBloc libraryBloc;

    final songA = Song(
      id: 10,
      title: 'Shape of You',
      artist: 'Ed Sheeran',
      album: 'Divide',
      filePath: '/music/shape_of_you.mp3',
      duration: const Duration(seconds: 240),
      dateModified: DateTime.now(),
    );

    final songB = Song(
      id: 20,
      title: 'Perfect',
      artist: 'Ed Sheeran',
      album: 'Divide',
      filePath: '/music/perfect.mp3',
      duration: const Duration(seconds: 260),
      dateModified: DateTime.now(),
    );

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      localDatasource = MusicLocalDatasourceImpl(db);
      repository = MusicRepositoryImpl(localDatasource);
      libraryBloc = LibraryBloc(
        repository: repository,
        fileService: MockFileService(),
        permissionService: MockPermissionService(),
      );
    });

    tearDown(() async {
      libraryBloc.close();
      await db.close();
    });

    test('Initial state is LibraryInitial', () {
      expect(libraryBloc.state, isA<LibraryInitial>());
    });

    blocTest<LibraryBloc, LibraryState>(
      'Loads songs from real database when LoadLibraryEvent is added',
      build: () => libraryBloc,
      act: (bloc) async {
        await repository.saveSongsBatch([songA, songB]);
        bloc.add(const LoadLibraryEvent());
      },
      expect: () => [
        isA<LibraryLoading>(),
        isA<LibraryLoaded>(),
      ],
      verify: (bloc) {
        expect(bloc.state, isA<LibraryLoaded>());
        final state = bloc.state as LibraryLoaded;
        expect(state.allSongs.length, equals(2));
        expect(state.allSongs.any((s) => s.title == 'Shape of You'), isTrue);
      },
    );

    blocTest<LibraryBloc, LibraryState>(
      'Filters songs by search query',
      build: () => libraryBloc,
      act: (bloc) async {
        await repository.saveSongsBatch([songA, songB]);
        bloc.add(const LoadLibraryEvent());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const SearchSongsEvent('Perfect'));
      },
      verify: (bloc) {
        expect(bloc.state, isA<LibraryLoaded>());
        final state = bloc.state as LibraryLoaded;
        expect(state.searchQuery, equals('Perfect'));
        expect(state.displayedSongs.length, equals(1));
        expect(state.displayedSongs.first.title, equals('Perfect'));
      },
    );

    blocTest<LibraryBloc, LibraryState>(
      'Creates playlist in database via CreatePlaylistEvent',
      build: () => libraryBloc,
      act: (bloc) async {
        bloc.add(const LoadLibraryEvent());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const CreatePlaylistEvent('Favorite Pop', description: 'Pop hits'));
      },
      verify: (bloc) {
        expect(bloc.state, isA<LibraryLoaded>());
        final state = bloc.state as LibraryLoaded;
        expect(state.playlists.any((p) => p.name == 'Favorite Pop'), isTrue);
      },
    );

    blocTest<LibraryBloc, LibraryState>(
      'Adds song to playlist via AddSongToPlaylistEvent',
      build: () => libraryBloc,
      act: (bloc) async {
        await repository.saveSongsBatch([songA]);
        final p = await repository.createPlaylist('Ed Sheeran Collection', null);
        bloc.add(const LoadLibraryEvent());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(AddSongToPlaylistEvent(p.id, songA));
      },
      verify: (bloc) {
        expect(bloc.state, isA<LibraryLoaded>());
        final state = bloc.state as LibraryLoaded;
        expect(state.playlists.first.songs.length, equals(1));
        expect(state.playlists.first.songs.first.title, equals('Shape of You'));
      },
    );
  });
}
