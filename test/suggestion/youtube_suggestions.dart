import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  print('========================================================');
  print('Querying YouTube Suggestion / Related graph for: "Boom Shaka"');
  print('========================================================');

  try {
    final search = await yt.search.search('Boom Shaka KR\$NA Dhanda Nyoliwala');
    if (search.isEmpty) {
      print('Seed track not found.');
      return;
    }

    final seed = search.first;
    print('✓ Seed Track: "${seed.title}" by ${seed.author} (ID: ${seed.id.value})\n');

    print('Fetching Related Songs...');
    final related = await yt.videos.getRelatedVideos(seed);
    if (related != null && related.isNotEmpty) {
      int count = 0;
      for (final v in related) {
        count++;
        print(' $count. "${v.title}" by ${v.author} [${v.duration}]');
        if (count >= 15) break;
      }
    } else {
      print('No related videos graph found, falling back to topic search...');
      final fallback = await yt.search.search('similar songs KR\$NA hip hop');
      for (var i = 0; i < fallback.take(10).length; i++) {
        final v = fallback[i];
        print(' ${i + 1}. "${v.title}" by ${v.author}');
      }
    }
  } catch (e) {
    print('Err: $e');
  } finally {
    yt.close();
  }
}
