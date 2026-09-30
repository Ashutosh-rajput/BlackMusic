import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl/data/models/song_model.dart';
import 'package:vinyl/data/models/playlist_model.dart';
import 'package:vinyl/data/repositories/music_repository.dart';
import 'package:vinyl/presentation/bloc/library/library_bloc.dart';
import 'package:vinyl/presentation/bloc/library/library_state.dart';
import 'package:vinyl/presentation/widgets/song_options_bottom_sheet.dart';
import 'package:vinyl/services/file_service.dart';
import 'package:vinyl/services/permission_service.dart';

/// Null implementations of all dependencies for LibraryBloc in tests.
class _NullMusicRepository extends MusicRepository {
  @override Stream<void> get onLibraryChanged => const Stream.empty();
  @override Future<List<Song>> getAllSongs() async => [];
  @override Future<void> addSong(Song s, {bool notify = true}) async {}
  @override Future<void> updateSong(Song s, {bool notify = true}) async {}
  @override Future<void> deleteSong(int id, {bool notify = true}) async {}
  @override Future<List<Song>> searchSongs(String q) async => [];
  @override Future<void> saveSongsBatch(List<Song> s, {bool notify = true}) async {}
  @override Future<void> incrementPlayCount(int id) async {}
  @override Future<void> recordSongPlay(Song s) async {}
  @override Future<List<Song>> getMostPlayedSongs({int limit = 20}) async => [];
  @override Future<List<Song>> getLastPlayedStreamSongs({int limit = 50}) async => [];
  @override Future<List<PlaylistModel>> getPlaylists() async => [];
  @override Future<PlaylistModel> createPlaylist(String name, String? desc, {bool notify = true}) async =>
      PlaylistModel(id: 1, name: name, dateCreated: DateTime.now(), dateModified: DateTime.now(), songs: const []);
  @override Future<void> deletePlaylist(int id, {bool notify = true}) async {}
  @override Future<void> addSongToPlaylist(int pid, Song s, {bool notify = true}) async {}
  @override Future<void> removeSongFromPlaylist(int pid, int sid, {bool notify = true}) async {}
}

Widget _wrapWithBloc(Widget child, {LibraryState? state}) {
  // We create the bloc and manually emit an initial state before providing it.
  final bloc = LibraryBloc(
    repository: _NullMusicRepository(),
    fileService: FileService(),
    permissionService: PermissionService(),
  );
  if (state != null) {
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(state);
  }
  return BlocProvider<LibraryBloc>.value(
    value: bloc,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('SongOptionsBottomSheet — stream/library separation', () {
    testWidgets('stream song: shows Download + Stream badge, no Delete/RemoveCache', (tester) async {
      final streamSong = Song(
        id: 99991,
        title: 'Live Stream Song',
        artist: 'Stream Artist',
        album: 'JioSaavn',
        filePath: 'https://media.jiosaavn.com/audio.mp4',
        duration: const Duration(seconds: 210),
        dateModified: DateTime.now(),
        source: 'jiosaavn',
      );

      bool downloadTriggered = false;

      await tester.pumpWidget(_wrapWithBloc(
        SongOptionsBottomSheet(
          song: streamSong,
          onDownload: () => downloadTriggered = true,
        ),
      ));

      expect(find.text('Live Stream Song'), findsOneWidget);
      expect(find.text('Stream Artist'), findsOneWidget);
      expect(find.text('Stream'), findsOneWidget); // badge

      expect(find.text('Start Radio'), findsOneWidget);
      expect(find.text('Add to Queue'), findsOneWidget);
      expect(find.text('Add to Playlist'), findsOneWidget);
      expect(find.text('Add to Favorites'), findsOneWidget);
      expect(find.text('Download Song'), findsOneWidget);

      // Destructive options NOT present for a live stream song
      expect(find.text('Delete from Library'), findsNothing);
      expect(find.text('Remove from Cache'), findsNothing);

      await tester.tap(find.text('Download Song'));
      await tester.pump();
      expect(downloadTriggered, isTrue);
    });

    testWidgets('local library song: shows Delete from Library, no Download or RemoveCache', (tester) async {
      final localSong = Song(
        id: 99992,
        title: 'Local Track',
        artist: 'Local Artist',
        album: 'My Downloads',
        filePath: '/storage/emulated/0/Music/track.mp3',
        duration: const Duration(seconds: 180),
        dateModified: DateTime.now(),
        source: 'youtube',  // <-- marks it as local library
        genre: 'Downloaded',
      );

      await tester.pumpWidget(_wrapWithBloc(
        SongOptionsBottomSheet(
          song: localSong,
          showDeleteFromLibrary: true,
          // Providing onDelete bypasses LibraryBloc in the handler,
          // but does NOT affect which action tiles are *shown*.
          onDelete: () {},
        ),
        state: const LibraryLoaded(allSongs: [], displayedSongs: [], playlists: []),
      ));

      await tester.pump();

      expect(find.text('Local Track'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget); // badge

      // Delete from Library shown, stream-only options NOT shown
      expect(find.text('Delete from Library'), findsOneWidget);
      expect(find.text('Remove from Cache'), findsNothing);
      expect(find.text('Download Song'), findsNothing);
    });
  });
}
