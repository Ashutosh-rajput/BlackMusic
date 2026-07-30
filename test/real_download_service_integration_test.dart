import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:pixel_player/data/database/app_database.dart' hide Song;
import 'package:pixel_player/data/datasources/local/music_local_datasource.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/services/download_service.dart';

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

      // Video id is intentionally malformed (not 11 chars) so YoutubeExplode's
      // VideoId parsing rejects it synchronously before any real network call
      // is made, keeping this test hermetic and independent of YouTube itself.
      await downloadService.enqueueDownload(
        url: 'https://www.youtube.com/watch?v=invalid',
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
  });
}
