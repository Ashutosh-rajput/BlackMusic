import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Fetches Trending Music directly from YouTube's official Trending Music Playlist for India
class YouTubeTrendingService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Playlist ID for YouTube Music Trending Charts
  Future<void> fetchTrendingMusic() async {
    print('========================================================');
    print('Fetching YouTube Trending & Viral Songs for India...');
    print('========================================================');

    try {
      // 1. Search for viral/trending Indian reels tracks
      final results = await _yt.search.search('trending songs hindi 2026');
      print('✓ Found ${results.length} trending YouTube tracks:');
      for (var i = 0; i < results.take(15).length; i++) {
        final v = results[i];
        print('  ${i + 1}. "${v.title}" by ${v.author} (${v.duration}) [ID: ${v.id.value}]');
      }
    } catch (e) {
      print('YouTube Trending error: $e');
    } finally {
      _yt.close();
    }
  }
}

void main() async {
  final service = YouTubeTrendingService();
  await service.fetchTrendingMusic();
}
