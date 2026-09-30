import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl/data/models/song_model.dart';
import 'package:vinyl/services/stream_playlists_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StreamPlaylistsService Tests', () {
    late StreamPlaylistsService service;

    final testSong1 = Song(
      id: 991,
      title: 'Stream Song 1',
      artist: 'Arijit Singh',
      album: 'Online Album',
      filePath: 'https://media.jiosaavn.com/test1.mp4',
      duration: const Duration(seconds: 210),
      dateModified: DateTime.now(),
      source: 'jiosaavn',
    );

    final testSong2 = Song(
      id: 992,
      title: 'Stream Song 2',
      artist: 'Pritam',
      album: 'Online Album 2',
      filePath: 'https://media.jiosaavn.com/test2.mp4',
      duration: const Duration(seconds: 180),
      dateModified: DateTime.now(),
      source: 'jiosaavn',
    );

    setUp(() async {
      service = StreamPlaylistsService.instance;
      await service.clearForTesting();
      await service.init();
    });

    tearDown(() async {
      await service.clearForTesting();
    });

    test('starts with empty playlists', () {
      expect(service.playlists, isEmpty);
      expect(service.count, equals(0));
    });

    test('createPlaylist creates and stores a new stream playlist', () async {
      final playlist = await service.createPlaylist('Chill Vibes', description: 'Stream Chill');

      expect(playlist.name, equals('Chill Vibes'));
      expect(playlist.description, equals('Stream Chill'));
      expect(service.count, equals(1));
      expect(service.getPlaylist(playlist.id), isNotNull);
    });

    test('addSongToPlaylist adds unique songs and prevents duplicates', () async {
      final playlist = await service.createPlaylist('Favorites');

      final added1 = await service.addSongToPlaylist(playlist.id, testSong1);
      expect(added1, isTrue);
      expect(service.isSongInPlaylist(playlist.id, testSong1.id), isTrue);

      // Attempting to add duplicate song should return false
      final addedAgain = await service.addSongToPlaylist(playlist.id, testSong1);
      expect(addedAgain, isFalse);

      final added2 = await service.addSongToPlaylist(playlist.id, testSong2);
      expect(added2, isTrue);

      final current = service.getPlaylist(playlist.id);
      expect(current?.songs.length, equals(2));
    });

    test('removeSongFromPlaylist removes specific song', () async {
      final playlist = await service.createPlaylist('Party');
      await service.addSongToPlaylist(playlist.id, testSong1);
      await service.addSongToPlaylist(playlist.id, testSong2);

      final removed = await service.removeSongFromPlaylist(playlist.id, testSong1.id);
      expect(removed, isTrue);
      expect(service.isSongInPlaylist(playlist.id, testSong1.id), isFalse);
      expect(service.isSongInPlaylist(playlist.id, testSong2.id), isTrue);
    });

    test('renamePlaylist renames existing playlist', () async {
      final playlist = await service.createPlaylist('Old Name');
      final renamed = await service.renamePlaylist(playlist.id, 'New Name');

      expect(renamed, isTrue);
      expect(service.getPlaylist(playlist.id)?.name, equals('New Name'));
    });

    test('deletePlaylist removes playlist from service', () async {
      final playlist = await service.createPlaylist('To Delete');
      expect(service.count, equals(1));

      final deleted = await service.deletePlaylist(playlist.id);
      expect(deleted, isTrue);
      expect(service.count, equals(0));
      expect(service.getPlaylist(playlist.id), isNull);
    });
  });
}
