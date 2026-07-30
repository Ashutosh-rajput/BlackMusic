import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:pixel_player/data/database/app_database.dart' hide Song;
import 'package:pixel_player/data/datasources/local/music_local_datasource.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:pixel_player/data/models/song_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('REAL Database & Repository Integration Tests (SQLite in-memory)', () {
    late AppDatabase db;
    late MusicLocalDatasourceImpl localDatasource;
    late MusicRepositoryImpl repository;

    final song1 = Song(
      id: 1,
      title: 'Midnight City',
      artist: 'M83',
      album: 'Hurry Up, We\'re Dreaming',
      filePath: '/storage/emulated/0/Music/midnight_city.mp3',
      duration: const Duration(seconds: 243),
      dateModified: DateTime.now(),
    );

    final song2 = Song(
      id: 2,
      title: 'Starboy',
      artist: 'The Weeknd',
      album: 'Starboy',
      filePath: '/storage/emulated/0/Music/starboy.mp3',
      duration: const Duration(seconds: 230),
      dateModified: DateTime.now(),
    );

    final song3 = Song(
      id: 3,
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      filePath: '/storage/emulated/0/Music/blinding_lights.mp3',
      duration: const Duration(seconds: 200),
      dateModified: DateTime.now(),
    );

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      localDatasource = MusicLocalDatasourceImpl(db);
      repository = MusicRepositoryImpl(localDatasource);
    });

    tearDown(() async {
      await db.close();
    });

    test('Insert and query songs from real SQLite database', () async {
      await repository.saveSongsBatch([song1, song2, song3]);

      final allSongs = await repository.getAllSongs();
      expect(allSongs.length, equals(3));
      expect(allSongs.any((s) => s.title == 'Midnight City'), isTrue);
      expect(allSongs.any((s) => s.title == 'Starboy'), isTrue);
    });

    test('Search songs by query in real SQLite database', () async {
      await repository.saveSongsBatch([song1, song2, song3]);

      final weekndSongs = await repository.searchSongs('Weeknd');
      expect(weekndSongs.length, equals(2));

      final midnightSearch = await repository.searchSongs('Midnight');
      expect(midnightSearch.length, equals(1));
      expect(midnightSearch.first.title, equals('Midnight City'));
    });

    test('Create playlist and add songs in real SQLite database', () async {
      await repository.saveSongsBatch([song1, song2, song3]);

      final createdPlaylist = await repository.createPlaylist('Synthwave Hits', 'Best synth tracks');
      expect(createdPlaylist.name, equals('Synthwave Hits'));
      expect(createdPlaylist.id, isNotNull);

      // Add song1 and song3 to playlist
      await repository.addSongToPlaylist(createdPlaylist.id, song1);
      await repository.addSongToPlaylist(createdPlaylist.id, song3);

      final playlists = await repository.getPlaylists();
      expect(playlists.length, equals(1));
      expect(playlists.first.songs.length, equals(2));
      expect(playlists.first.songs.any((s) => s.title == 'Midnight City'), isTrue);
      expect(playlists.first.songs.any((s) => s.title == 'Blinding Lights'), isTrue);
    });

    test('Delete song from playlist and delete playlist in real SQLite database', () async {
      await repository.saveSongsBatch([song1, song2]);

      final playlist = await repository.createPlaylist('Test Playlist', null);
      await repository.addSongToPlaylist(playlist.id, song1);
      await repository.addSongToPlaylist(playlist.id, song2);

      var fetchedPlaylists = await repository.getPlaylists();
      expect(fetchedPlaylists.first.songs.length, equals(2));

      // Remove song1 from playlist
      await repository.removeSongFromPlaylist(playlist.id, song1.id);
      fetchedPlaylists = await repository.getPlaylists();
      expect(fetchedPlaylists.first.songs.length, equals(1));
      expect(fetchedPlaylists.first.songs.first.id, equals(song2.id));

      // Delete playlist
      await repository.deletePlaylist(playlist.id);
      fetchedPlaylists = await repository.getPlaylists();
      expect(fetchedPlaylists.isEmpty, isTrue);
    });
  });
}
