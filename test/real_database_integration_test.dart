import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:vinyl/data/database/app_database.dart' hide Song;
import 'package:vinyl/data/datasources/local/music_local_datasource.dart';
import 'package:vinyl/data/repositories/music_repository.dart';
import 'package:vinyl/data/models/song_model.dart';

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

    test('Deleting song cascades and cleans up playlist_songs, lyrics, and play_history', () async {
      await repository.addSong(song1);
      final playlist = await repository.createPlaylist('Favorites', null);
      await repository.addSongToPlaylist(playlist.id, song1);
      await db.saveLyrics(songId: song1.id, content: 'Some lyrics', format: 'plain');
      await repository.recordSongPlay(song1);

      // Verify records exist
      expect(await db.getSongIdsForPlaylist(playlist.id), contains(song1.id));
      expect(await db.getLyricsBySongId(song1.id), isNotNull);
      final historyBefore = await db.getPlayHistory();
      expect(historyBefore.any((h) => h.songId == song1.id), isTrue);

      // Delete the song
      await repository.deleteSong(song1.id);

      // Verify song is deleted from songs table
      final allSongs = await repository.getAllSongs();
      expect(allSongs.any((s) => s.id == song1.id), isFalse);

      // Verify cascade deleted from playlistSongs, lyrics, and playHistory
      expect(await db.getSongIdsForPlaylist(playlist.id), isEmpty);
      expect(await db.getLyricsBySongId(song1.id), isNull);
      final historyAfter = await db.getPlayHistory();
      expect(historyAfter.any((h) => h.songId == song1.id), isFalse);
    });

    test('streaming a song that is already downloaded keeps the download in the Library', () async {
      // The downloaded copy, saved to the device.
      final downloaded = Song(
        id: 7001,
        title: 'Kesariya',
        artist: 'Arijit Singh',
        album: 'Brahmastra',
        filePath: '/storage/emulated/0/Download/vinyl/Kesariya.m4a',
        duration: const Duration(seconds: 268),
        dateModified: DateTime.now(),
        genre: 'Downloaded',
        source: 'jiosaavn',
      );
      await repository.addSong(downloaded);

      // The same song played again from Stream: different id, stream URL.
      final streamed = Song(
        id: 7002,
        title: 'Kesariya',
        artist: 'Arijit Singh',
        album: 'Brahmastra',
        filePath: 'https://aac.saavncdn.com/123/kesariya_320.mp4',
        duration: const Duration(seconds: 268),
        dateModified: DateTime.now(),
        source: 'jiosaavn',
      );
      await repository.recordSongPlay(streamed);

      final library = await repository.getAllSongs();
      final kept = library.where((s) => s.title == 'Kesariya').toList();
      expect(kept, hasLength(1));
      expect(kept.single.filePath, equals('/storage/emulated/0/Download/vinyl/Kesariya.m4a'));
      // The Stream play is counted on the Stream side, not on the download.
      final streamHistory = await repository.getLastPlayedStreamSongs();
      expect(streamHistory.map((s) => s.title), contains('Kesariya'));
    });

    test('a Stream song keeps its JioSaavn id after being saved and read back', () async {
      final played = Song(
        id: 9101,
        mediaId: 'Jv9R7q1X',
        title: 'Kesariya',
        artist: 'Arijit Singh',
        album: 'Brahmastra',
        filePath: 'https://aac.saavncdn.com/9/kesariya_320.mp4',
        duration: const Duration(seconds: 268),
        dateModified: DateTime.now(),
        source: 'jiosaavn',
      );
      await repository.recordSongPlay(played);

      // Read back from the database (as Autoplay / Last Played do).
      final history = await repository.getLastPlayedStreamSongs();
      expect(history.single.mediaId, equals('Jv9R7q1X'));

      // An older row saved without the id gets it filled in on the next play.
      await db.into(db.songs).insertOnConflictUpdate(
            SongsCompanion.insert(
              id: const Value(9102),
              title: 'Old Row',
              artist: 'Old Artist',
              album: 'JioSaavn',
              filePath: 'https://aac.saavncdn.com/9/old_row.mp4',
              duration: 180000,
              dateModified: DateTime.now(),
              source: const Value('jiosaavn'),
              lastPlayedAt: Value(DateTime.now()),
            ),
          );
      await repository.recordSongPlay(Song(
        id: 9102,
        mediaId: 'OldRowId1',
        title: 'Old Row',
        artist: 'Old Artist',
        album: 'JioSaavn',
        filePath: 'https://aac.saavncdn.com/9/old_row.mp4',
        duration: const Duration(seconds: 180),
        dateModified: DateTime.now(),
        source: 'jiosaavn',
      ));
      final after = await repository.getLastPlayedStreamSongs();
      expect(after.firstWhere((s) => s.title == 'Old Row').mediaId, equals('OldRowId1'));
    });

    group('Library and Stream stay separate', () {
      Song streamSong(int id, String title, String path) => Song(
            id: id,
            title: title,
            artist: 'Stream Artist',
            album: 'JioSaavn',
            filePath: path,
            duration: const Duration(seconds: 200),
            dateModified: DateTime.now(),
            source: 'jiosaavn',
          );

      test('a song played from the offline stream cache never appears in the Library', () async {
        await repository.recordSongPlay(streamSong(
          8001,
          'Cached Stream Song',
          '/data/user/0/com.muskmelon.vinyl/cache/stream_cache/8001.m4a',
        ));
        await repository.recordSongPlay(streamSong(8002, 'Unresolved Stream Song', ''));

        final library = await repository.getAllSongs();
        expect(library.any((s) => s.title.contains('Stream Song')), isFalse);
        final search = await repository.searchSongs('Stream Song');
        expect(search, isEmpty);
      });

      test('Stream "Last Played" contains only Stream songs', () async {
        await repository.addSong(song1); // a Library file
        await repository.recordSongPlay(song1);
        await repository.recordSongPlay(
            streamSong(8003, 'Online Hit', 'https://aac.saavncdn.com/1/online_hit_320.mp4'));

        final lastPlayed = await repository.getLastPlayedStreamSongs();
        expect(lastPlayed.map((s) => s.title), contains('Online Hit'));
        expect(lastPlayed.any((s) => s.title == song1.title), isFalse);

        final topStream = await repository.getMostPlayedSongs(streamOnly: true);
        expect(topStream.any((s) => s.title == song1.title), isFalse);
      });

      test('a Library play never updates a Stream song with the same title', () async {
        await repository.recordSongPlay(streamSong(
            8004, song1.title, 'https://aac.saavncdn.com/2/midnight_city_320.mp4').copyWith(artist: song1.artist));
        await repository.addSong(song1);
        await repository.recordSongPlay(song1);

        // The Library file keeps its own path; the Stream row keeps its URL.
        final library = await repository.getAllSongs();
        expect(library.where((s) => s.title == song1.title).single.filePath, equals(song1.filePath));
        final stream = await repository.getLastPlayedStreamSongs();
        expect(stream.where((s) => s.title == song1.title).single.filePath, startsWith('https://'));
      });
    });
  });
}

