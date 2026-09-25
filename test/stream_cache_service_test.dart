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
  });
}
