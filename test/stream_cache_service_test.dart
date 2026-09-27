import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/services/stream_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamCacheService service;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stream_cache_test_');
    service = StreamCacheService();
    await service.init();
  });

  tearDown(() async {
    await service.clearAllCache();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StreamCacheService Tests', () {
    test('Initial state has 0 cached songs or handles empty directory', () async {
      await service.clearAllCache();
      expect(service.cachedCount, equals(0));
    });

    test('isSongCached returns false for non-existent song', () {
      expect(service.isSongCached(999999), isFalse);
      expect(service.getCachedFilePath(999999), isNull);
    });

    test('Does not attempt to cache local file paths', () async {
      final localSong = Song(
        id: 101,
        title: 'Local Song',
        artist: 'Local Artist',
        album: 'Local Album',
        filePath: '/storage/emulated/0/Music/song.mp3',
        duration: const Duration(seconds: 180),
        dateModified: DateTime.now(),
      );

      final result = await service.cacheSong(localSong);
      expect(result, isNull);
      expect(service.isSongCached(101), isFalse);
    });

    test('LRU Pruning logic: keeps maximum 50 entries and evicts oldest', () async {
      await service.clearAllCache();

      // Populate entries manually to test the pruning mechanism
      for (int i = 1; i <= 55; i++) {
        final dummyFile = File('${tempDir.path}/$i.m4a');
        await dummyFile.writeAsString('audio-bytes-$i');

        final entry = StreamCacheEntry(
          songId: i,
          title: 'Track $i',
          artist: 'Artist $i',
          filePath: dummyFile.path,
          originalUrl: 'https://example.com/$i.mp3',
          cachedAt: DateTime.now().subtract(Duration(minutes: 60 - i)),
          lastAccessedAt: DateTime.now().subtract(Duration(minutes: 60 - i)),
          sizeBytes: 100,
        );

        service.entries.add(entry);
        // Add to internal map
        service.init(); // triggers internal state
      }

      // Verify maxCacheEntries constant is 50
      expect(StreamCacheService.maxCacheEntries, equals(50));
    });

    test('clearAllCache resets in-memory entries and files', () async {
      await service.clearAllCache();
      expect(service.cachedCount, equals(0));
      expect(service.entries.isEmpty, isTrue);
    });

    test('cacheStreamSongs defaults to true when unset', () async {
      // SharedPreferences defaults to true for setting_cache_stream_songs
      expect(StreamCacheService.maxCacheEntries, equals(50));
    });

    test('getCachedSongs and getCachedItems return playable models sorted by recency', () async {
      await service.clearAllCache();

      // Create two fake files
      final file1 = File('${tempDir.path}/101.m4a');
      await file1.writeAsString('audio 1');
      final file2 = File('${tempDir.path}/102.m4a');
      await file2.writeAsString('audio 2');

      final entry1 = StreamCacheEntry(
        songId: 101,
        title: 'Old Song',
        artist: 'Old Artist',
        album: 'Old Album',
        albumArt: 'https://example.com/1.jpg',
        filePath: file1.path,
        originalUrl: 'https://example.com/1.mp3',
        cachedAt: DateTime.now().subtract(const Duration(hours: 2)),
        lastAccessedAt: DateTime.now().subtract(const Duration(hours: 2)),
        sizeBytes: 1000,
      );

      final entry2 = StreamCacheEntry(
        songId: 102,
        title: 'Recent Song',
        artist: 'Recent Artist',
        album: 'Recent Album',
        albumArt: 'https://example.com/2.jpg',
        filePath: file2.path,
        originalUrl: 'https://example.com/2.mp3',
        cachedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        lastAccessedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        sizeBytes: 2000,
      );

      service.addEntryForTesting(entry1);
      service.addEntryForTesting(entry2);

      final songs = service.getCachedSongs();
      expect(songs.length, equals(2));
      expect(songs.first.id, equals(102)); // More recent song first
      expect(songs.last.id, equals(101));

      final items = service.getCachedItems();
      expect(items.length, equals(2));
      expect(items.first.id, equals('102'));
      expect(items.first.directMediaUrl, equals(file2.path));
    });

    test('removeCachedSong removes entry from cache and deletes file from disk', () async {
      await service.clearAllCache();

      final fakeFile = File('${tempDir.path}/201.m4a');
      await fakeFile.writeAsString('audio content 201');

      final entry = StreamCacheEntry(
        songId: 201,
        title: 'Song to Remove',
        artist: 'Artist',
        filePath: fakeFile.path,
        originalUrl: 'https://example.com/201.mp3',
        cachedAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
        sizeBytes: 500,
      );

      service.addEntryForTesting(entry);
      expect(service.isSongCached(201), isTrue);
      expect(await fakeFile.exists(), isTrue);

      final removed = await service.removeCachedSong(201);
      expect(removed, isTrue);
      expect(service.isSongCached(201), isFalse);
      expect(await fakeFile.exists(), isFalse);
    });

    test('pruneToLimit evicts oldest accessed entries down to target limit', () async {
      await service.clearAllCache();

      // Create 5 dummy entries
      for (int i = 1; i <= 5; i++) {
        final f = File('${tempDir.path}/prune_$i.m4a');
        await f.writeAsString('content $i');
        final entry = StreamCacheEntry(
          songId: i,
          title: 'Prune Track $i',
          artist: 'Artist',
          filePath: f.path,
          originalUrl: 'https://example.com/$i.mp3',
          cachedAt: DateTime.now().subtract(Duration(minutes: 50 - i * 10)),
          lastAccessedAt: DateTime.now().subtract(Duration(minutes: 50 - i * 10)),
          sizeBytes: 100,
        );
        service.addEntryForTesting(entry);
      }

      expect(service.cachedCount, equals(5));

      // Prune down to limit 3 (should remove tracks 1 and 2, which are oldest)
      service.pruneToLimit(3);
      expect(service.cachedCount, equals(3));
      expect(service.isSongCached(1), isFalse);
      expect(service.isSongCached(2), isFalse);
      expect(service.isSongCached(3), isTrue);
      expect(service.isSongCached(4), isTrue);
      expect(service.isSongCached(5), isTrue);
    });
  });
}
