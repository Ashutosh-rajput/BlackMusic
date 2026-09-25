import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_player/core/utils/jiosaavn_decoder.dart';

void main() {
  group('JioSaavnDecoder Unit Tests', () {
    test('Decrypts encrypted_media_url to valid 320kbps HTTPS audio URL', () {
      // Real encrypted media URL from JioSaavn API for song "Qatal"
      const encrypted =
          'ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDyBjZ8W9LFMH5fb5Y4m6Jvbsmw9Mk0y4YpNGm/fiPt+fT45YhcdPQXyxw7tS9a8Gtq';

      final decUrl = JioSaavnDecoder.decryptMediaUrl(encrypted);

      expect(decUrl, isNotNull);
      expect(decUrl!.startsWith('https://'), isTrue);
      expect(decUrl.contains('.saavncdn.com'), isTrue);
      expect(decUrl.endsWith('_320.mp4'), isTrue);
    });

    test('Handles null and empty string safely', () {
      expect(JioSaavnDecoder.decryptMediaUrl(null), isNull);
      expect(JioSaavnDecoder.decryptMediaUrl(''), isNull);
      expect(JioSaavnDecoder.decryptMediaUrl('   '), isNull);
      expect(JioSaavnDecoder.decryptMediaUrl('not-valid-base64'), isNull);
    });

    test('fetchSongSuggestions handles empty song ID safely', () async {
      final suggestions = await JioSaavnDecoder.fetchSongSuggestions('');
      expect(suggestions, isEmpty);

      final whitespaceSuggestions = await JioSaavnDecoder.fetchSongSuggestions('   ');
      expect(whitespaceSuggestions, isEmpty);
    });

    test('fetchSongSuggestions returns real suggestions for valid song ID', () async {
      final suggestions = await JioSaavnDecoder.fetchSongSuggestions('xNVbUezC', limit: 5);
      expect(suggestions.isNotEmpty, isTrue);
      expect(suggestions.first.title.isNotEmpty, isTrue);
    });

    test('parseItem extracts subtitle from artistMap if subtitle is empty', () {
      final item = JioSaavnDecoder.parseItem({
        'id': 'test_song_1',
        'title': 'Test Track',
        'subtitle': '',
        'more_info': {
          'artistMap': {
            'primary_artists': [
              {'name': 'Pritam'},
              {'name': 'Arijit Singh'},
            ],
          },
        },
      });

      expect(item.id, equals('test_song_1'));
      expect(item.title, equals('Test Track'));
      expect(item.subtitle, equals('Pritam, Arijit Singh'));
    });
  });
}

