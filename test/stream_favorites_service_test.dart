import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_player/data/models/jiosaavn_item.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/services/stream_favorites_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StreamFavoritesService Tests', () {
    late StreamFavoritesService service;

    final testSong = Song(
      id: 99991,
      title: 'Stream Song 1',
      artist: 'Arijit Singh',
      album: 'Online Album',
      filePath: 'https://media.jiosaavn.com/test1.mp4',
      duration: const Duration(seconds: 210),
      dateModified: DateTime.now(),
      source: 'jiosaavn',
    );

    final testItem = JioSaavnItem(
      type: 'song',
      id: '88882',
      token: 'tok88882',
      title: 'Stream Song 2',
      subtitle: 'Pritam',
      imageUrl: 'https://example.com/art.jpg',
    );

    setUp(() async {
      service = StreamFavoritesService.instance;
      await service.clearForTesting();
      await service.init();
    });

    tearDown(() async {
      await service.clearForTesting();
    });

    test('starts empty', () {
      expect(service.favorites, isEmpty);
      expect(service.count, 0);
      expect(service.isFavorite(testSong.id), isFalse);
    });

    test('toggleFavorite adds then removes song', () async {
      final added = await service.toggleFavorite(testSong);
      expect(added, isTrue);
      expect(service.isFavorite(testSong.id), isTrue);
      expect(service.count, 1);
      expect(service.favorites.first.title, 'Stream Song 1');

      final removed = await service.toggleFavorite(testSong);
      expect(removed, isFalse);
      expect(service.isFavorite(testSong.id), isFalse);
      expect(service.count, 0);
    });

    test('onFavoritesChanged stream emits updates', () async {
      expectLater(
        service.onFavoritesChanged,
        emitsInOrder([
          predicate<List<Song>>((list) => list.length == 1 && list.first.id == testSong.id),
          predicate<List<Song>>((list) => list.isEmpty),
        ]),
      );

      await service.toggleFavorite(testSong);
      await service.removeFavorite(testSong.id);
    });

    test('isItemFavorite works with JioSaavnItem', () async {
      final songFromItem = testItem.toSong();
      expect(service.isItemFavorite(testItem), isFalse);

      await service.toggleFavorite(songFromItem);
      expect(service.isItemFavorite(testItem), isTrue);
      expect(service.isFavorite(songFromItem.id), isTrue);
    });
  });
}
