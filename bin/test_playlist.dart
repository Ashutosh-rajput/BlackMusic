// ignore_for_file: avoid_print
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main() async {
  final yt = YoutubeExplode();
  final dio = Dio();

  const url =
      "https://youtube.com/playlist?list=PLOcASI4VrVsYQ2JCESwzAjJbjtNZSSrkk";

  print("Connecting to YouTube Playlist...");
  final playlist = await yt.playlists.get(url);

  print("Title: ${playlist.title}");
  print("Author: ${playlist.author}");
  print("Count reported: ${playlist.videoCount}");

  print("\n--- 1. Testing youtube_explode_dart getVideos() ---");
  int count1 = 0;
  try {
    await for (final video in yt.playlists.getVideos(playlist.id)) {
      count1++;
      print("1. [$count1] ${video.title} (${video.id})");
    }
  } catch (e) {
    print("getVideos error: $e");
  }
  print("Total fetched via getVideos(): $count1");

  if (count1 == 0) {
    print("\n--- 2. Testing HTTP HTML Fallback ---");
    final response = await dio.get(
      url,
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        },
      ),
    );

    final html = response.data.toString();
    final matches = RegExp(r'"videoId":"([a-zA-Z0-9_-]{11})"').allMatches(html);
    final videoIds = <String>{};

    for (final match in matches) {
      final id = match.group(1);
      if (id != null) videoIds.add(id);
    }

    print("Total fetched via HTML fallback: ${videoIds.length}");
    int count2 = 0;
    for (final id in videoIds) {
      count2++;
      print("2. [$count2] Video ID: $id -> https://www.youtube.com/watch?v=$id");
    }
  }

  yt.close();
}
