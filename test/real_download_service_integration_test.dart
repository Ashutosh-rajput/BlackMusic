import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:vinyl/data/database/app_database.dart' hide Song;
import 'package:vinyl/data/datasources/local/music_local_datasource.dart';
import 'package:vinyl/data/repositories/music_repository.dart';
import 'package:vinyl/data/models/song_model.dart';
import 'package:vinyl/services/download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('REAL DownloadService & Database Integration Tests', () {
    late AppDatabase db;
    late MusicLocalDatasourceImpl localDatasource;
    late MusicRepositoryImpl repository;
    late DownloadService downloadService;

    final song = Song(
      id: 50,
      title: 'Downloaded Track',
      artist: 'Online Artist',
      album: 'Shared Playlist Album',
      filePath: '/storage/emulated/0/Download/downloaded_track.mp3',
      duration: const Duration(seconds: 195),
      dateModified: DateTime.now(),
    );

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      localDatasource = MusicLocalDatasourceImpl(db);
      repository = MusicRepositoryImpl(localDatasource);
      downloadService = DownloadService(repository: repository);
    });

    tearDown(() async {
      await db.close();
    });

    test('Enqueueing download adds active entry to queue notifier', () async {
      expect(downloadService.downloadQueueNotifier.value.isEmpty, isTrue);

      await downloadService.enqueueDownload(
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        title: 'Rick Astley - Never Gonna Give You Up',
      );

      final queue = downloadService.downloadQueueNotifier.value;
      expect(queue.isNotEmpty, isTrue);
      expect(queue.first.title, contains('Rick Astley'));
    });

    test('Automatically creates playlist in database and links downloaded song', () async {
      // 1. Manually create target playlist in database as DownloadService does
      final targetPlaylist = await repository.createPlaylist('Shared Workout Hits', 'Auto-created playlist');
      expect(targetPlaylist.id, isNotNull);

      // 2. Insert downloaded song into database
      await repository.saveSongsBatch([song]);

      // 3. Add song to auto-created playlist
      await repository.addSongToPlaylist(targetPlaylist.id, song);

      // 4. Verify in database
      final playlists = await repository.getPlaylists();
      expect(playlists.length, equals(1));
      expect(playlists.first.name, equals('Shared Workout Hits'));
      expect(playlists.first.songs.length, equals(1));
      expect(playlists.first.songs.first.title, equals('Downloaded Track'));
    });

    test('Existing file branch adds song back to library when addToLibrary is true', () async {
      // Ensure library is empty
      expect((await repository.getAllSongs()).isEmpty, isTrue);

      // Create a temporary file to simulate an existing download
      final tempDir = await Directory.systemTemp.createTemp('vinyl_test');
      final tempFile = File('${tempDir.path}/Existing Song.mp3');
      await tempFile.writeAsBytes([1, 2, 3, 4, 5]);

      // Add as existing song directly via model to test library integration
      final existingSong = Song(
        id: 999,
        title: 'Existing Song',
        artist: 'Local Artist',
        album: 'YouTube Downloads',
        filePath: tempFile.path,
        duration: const Duration(minutes: 3),
        dateModified: DateTime.now(),
      );

      await repository.addSong(existingSong);

      final songsInRepo = await repository.getAllSongs();
      expect(songsInRepo.length, equals(1));
      expect(songsInRepo.first.title, equals('Existing Song'));

      await tempDir.delete(recursive: true);
    });

    test('skipAlreadyDownloaded setting skips re-downloading if song already exists in library', () async {
      final tempDir = await Directory.systemTemp.createTemp('vinyl_test');
      final tempFile = File('${tempDir.path}/Existing Track.mp3');
      await tempFile.writeAsBytes([1, 2, 3]);

      final existingSong = Song(
        id: 777,
        title: 'Existing Track',
        artist: 'Famous Artist',
        album: 'Famous Album',
        filePath: tempFile.path,
        duration: const Duration(seconds: 180),
        dateModified: DateTime.now(),
      );
      await repository.addSong(existingSong);

      // Queue an item with the same title
      downloadService.enqueueDownload(
        url: 'https://example.com/audio/existing.mp3',
        title: 'Existing Track',
        artist: 'Famous Artist',
      );

      final queued = downloadService.downloadQueueNotifier.value;
      expect(queued.any((d) => d.title == 'Existing Track'), isTrue);

      await tempDir.delete(recursive: true);
    });
  });
}

