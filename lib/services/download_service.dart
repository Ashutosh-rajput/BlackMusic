import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class DownloadService {
  final MusicRepository _repository;
  final Dio _dio = Dio();

  DownloadService(this._repository);

  /// Main entry point: Detects link platform and downloads high-quality audio file.
  Future<Song?> downloadFromUrl({
    required String url,
    required Function(double progress, String status) onProgress,
  }) async {
    final cleanUrl = _extractFirstUrl(url.trim());
    if (cleanUrl.isEmpty) {
      throw Exception('Invalid or empty URL provided.');
    }

    if (_isPlaylistUrl(cleanUrl)) {
      final songs = await downloadPlaylist(
        url: cleanUrl,
        onProgress: (current, total, songProgress, title) {
          final overall = (current > 0 ? (current - 1 + songProgress) : 0.0) / total;
          onProgress(
            overall.clamp(0.0, 1.0),
            '[$current/$total] $title',
          );
        },
      );
      return songs.isNotEmpty ? songs.first : null;
    }

    if (_isYoutubeUrl(cleanUrl)) {
      return await _downloadYoutube(cleanUrl, onProgress);
    } else {
      return await _downloadDirectAudio(cleanUrl, onProgress);
    }
  }

  bool _isPlaylistUrl(String url) {
    return url.toLowerCase().contains('list=');
  }

  bool _isYoutubeUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('youtube.com/shorts');
  }

  String _extractFirstUrl(String text) {
    final regex = RegExp(r'https?://[^\s]+');
    final match = regex.firstMatch(text);
    return match?.group(0) ?? text;
  }

  Future<String> _getMusicDirectoryPath() async {
    if (Platform.isAndroid) {
      try {
        final publicDownloadDir = Directory('/storage/emulated/0/Download/blackmusic');
        if (!await publicDownloadDir.exists()) {
          await publicDownloadDir.create(recursive: true);
        }
        return publicDownloadDir.path;
      } catch (e) {
        _logger.w('Could not write to public Download/blackmusic directory ($e), falling back to app music directory...');
        try {
          final extDirs = await getExternalStorageDirectories(type: StorageDirectory.music);
          if (extDirs != null && extDirs.isNotEmpty) {
            final dir = extDirs.first;
            if (!await dir.exists()) {
              await dir.create(recursive: true);
            }
            return dir.path;
          }
        } catch (_) {}
      }
    }
    final appDir = await getApplicationDocumentsDirectory();
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir.path;
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  String _cleanYoutubeUrl(String url) {
    final videoIdMatch = RegExp(r'(?:v=|\/|be\/)([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (videoIdMatch != null && videoIdMatch.groupCount >= 1) {
      final id = videoIdMatch.group(1);
      if (id != null) return 'https://www.youtube.com/watch?v=$id';
    }
    return url;
  }

  Future<Song?> _downloadYoutube(
    String url,
    Function(double progress, String status) onProgress,
  ) async {
    final cleanUrl = _cleanYoutubeUrl(url);
    final yt = YoutubeExplode();

    File? activeFile;
    try {
      onProgress(0.05, 'Parsing YouTube link...');
      final videoId = VideoId(cleanUrl).value;

      onProgress(0.10, 'Fetching video info...');
      final video = await yt.videos.get(videoId);
      final title = _sanitizeFileName(video.title);
      final artist = video.author;
      final duration = video.duration ?? Duration.zero;
      final albumArt = video.thumbnails.highResUrl;

      onProgress(0.20, 'Getting stream manifest...');
      final manifest = await yt.videos.streamsClient.getManifest(videoId);

      // Select stream in order of reliability & quality:
      // 1. M4A audio-only streams
      // 2. Pre-muxed MP4 streams (100% reliable direct download)
      // 3. General audio streams (WebM fallback)
      StreamInfo? selectedStream;
      final m4aStreams = manifest.audioOnly.where((s) => s.container.name.toLowerCase() == 'm4a').toList();
      if (m4aStreams.isNotEmpty) {
        selectedStream = m4aStreams.withHighestBitrate();
      } else if (manifest.muxed.isNotEmpty) {
        selectedStream = manifest.muxed.withHighestBitrate();
      } else if (manifest.audioOnly.isNotEmpty) {
        selectedStream = manifest.audioOnly.withHighestBitrate();
      }

      if (selectedStream != null) {
        final musicDirPath = await _getMusicDirectoryPath();
        final containerName = selectedStream.container.name.toLowerCase();
        final ext = containerName == 'mp4' ? 'm4a' : containerName;
        final savePath = '$musicDirPath/$title.$ext';
        activeFile = File(savePath);

        final totalBytes = selectedStream.size.totalBytes;
        final streamUrl = selectedStream.url;
        _logger.i('[YT_DOWNLOAD 1/3] Video: "$title" ($videoId)');
        _logger.i('[YT_DOWNLOAD 2/3] Stream selected: $ext, bitrate: ${selectedStream.bitrate}, totalBytes: $totalBytes');
        assert(() {
          _logger.i('[YT_DOWNLOAD URL] Stream Direct Link: $streamUrl');
          return true;
        }());
        onProgress(0.30, 'Downloading "${video.title}"...');

        // Try Dio direct stream download first, fallback to YoutubeExplode streamsClient
        try {
          await _dio.download(
            streamUrl.toString(),
            savePath,
            options: Options(
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
              },
              receiveTimeout: const Duration(seconds: 120),
              connectTimeout: const Duration(seconds: 15),
            ),
            onReceiveProgress: (received, total) {
              final effectiveTotal = total > 0 ? total : totalBytes;
              if (effectiveTotal > 0) {
                final p = 0.30 + (received / effectiveTotal) * 0.65;
                onProgress(
                  p.clamp(0.0, 0.95),
                  'Downloading "${video.title}"... (${(p * 100).toInt()}%)',
                );
              } else {
                onProgress(
                  0.50,
                  'Downloading "${video.title}"... ${(received / 1024 / 1024).toStringAsFixed(1)} MB',
                );
              }
            },
          );
        } catch (dioErr) {
          _logger.w('[YT_DOWNLOAD] Dio direct download failed ($dioErr), trying YoutubeExplode streamsClient...');
          final stream = yt.videos.streamsClient.get(selectedStream);
          final sink = activeFile.openWrite();
          int downloaded = 0;

          try {
            await for (final chunk in stream) {
              downloaded += chunk.length;
              sink.add(chunk);

              if (totalBytes > 0) {
                final p = 0.30 + (downloaded / totalBytes) * 0.65;
                onProgress(
                  p.clamp(0.0, 0.95),
                  'Downloading "${video.title}"... (${(p * 100).toInt()}%)',
                );
              } else {
                onProgress(
                  0.50,
                  'Downloading "${video.title}"... ${(downloaded / 1024 / 1024).toStringAsFixed(1)} MB',
                );
              }
            }
          } finally {
            await sink.flush();
            await sink.close();
          }
        }

        _logger.i('[YT_DOWNLOAD 3/3] Download finished naturally.');

        final savedLength = await activeFile.length();
        if (savedLength == 0 || (totalBytes > 0 && savedLength != totalBytes)) {
          _logger.w('[YT_DOWNLOAD incomplete] Expected $totalBytes bytes, received $savedLength. Cleaning up partial file...');
          if (await activeFile.exists()) {
            await activeFile.delete();
          }
          throw Exception('Incomplete download: expected $totalBytes bytes, received $savedLength');
        }

        onProgress(0.98, 'Saving to Music Library...');
        final song = Song(
          id: savePath.hashCode.abs(),
          title: video.title,
          artist: artist,
          album: 'YouTube Downloads',
          filePath: savePath,
          duration: duration,
          fileSize: savedLength,
          dateModified: DateTime.now(),
          genre: 'Downloaded',
          albumArtist: artist,
          albumArt: albumArt,
        );

        await _repository.addSong(song);
        onProgress(1.0, 'Download complete!');
        return song;
      }
      throw Exception('No valid audio stream found for this video.');
    } catch (e) {
      if (activeFile != null && await activeFile.exists()) {
        try {
          _logger.w('[YT_DOWNLOAD] Cleaning up partial download file: ${activeFile.path}');
          await activeFile.delete();
        } catch (_) {}
      }
      _logger.e('YouTube download failed: $e');
      throw Exception(
        'Unable to download this track. The video may be unavailable, age-restricted, or temporarily unsupported.',
      );
    } finally {
      yt.close();
    }
  }

  /// Downloads an entire YouTube playlist sequentially with duplicate skipping,
  /// overall progress, and cancellation support.
  Future<List<Song>> downloadPlaylist({
    required String url,
    required Function(
      int current,
      int total,
      double currentSongProgress,
      String title,
    ) onProgress,
    bool Function()? isCanceled,
  }) async {
    final cleanUrl = _extractFirstUrl(url.trim());
    final yt = YoutubeExplode();
    final downloadedSongs = <Song>[];

    try {
      onProgress(0, 1, 0.05, 'Fetching playlist info...');
      final playlist = await yt.playlists.get(cleanUrl);

      _logger.i("Title: ${playlist.title}");
      _logger.i("ID: ${playlist.id}");
      _logger.i("Video count reported: ${playlist.videoCount}");

      final videoUrls = <String>[];
      try {
        await for (final video in yt.playlists.getVideos(playlist.id)) {
          videoUrls.add(video.url);
        }
      } catch (e) {
        _logger.w('yt.playlists.getVideos error: $e');
      }

      if (videoUrls.isEmpty) {
        _logger.w('yt.playlists.getVideos returned 0 videos due to YouTube layout changes. Extracting video IDs via HTML fallback...');
        try {
          final response = await _dio.get(
            cleanUrl,
            options: Options(
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
              },
            ),
          );
          final html = response.data.toString();
          final matches = RegExp(r'"videoId":"([a-zA-Z0-9_-]{11})"').allMatches(html);
          final seenIds = <String>{};
          for (final match in matches) {
            final id = match.group(1);
            if (id != null && seenIds.add(id)) {
              videoUrls.add('https://www.youtube.com/watch?v=$id');
            }
          }
        } catch (e) {
          _logger.e('HTML playlist video extraction error: $e');
        }
      }

      _logger.i('Total playlist videos queued for download: ${videoUrls.length}');

      final totalSongs = videoUrls.length;
      for (int i = 0; i < totalSongs; i++) {
        if (isCanceled?.call() == true) {
          _logger.i('Playlist download canceled by user.');
          break;
        }

        final videoUrl = videoUrls[i];
        final index = i + 1;

        try {
          final song = await _downloadYoutube(
            videoUrl,
            (songProgress, status) {
              onProgress(index, totalSongs, songProgress, status);
            },
          );
          if (song != null) {
            downloadedSongs.add(song);
          }
        } catch (e) {
          _logger.w('Failed to download playlist track $index ("$videoUrl"): $e');
        }
      }

      _logger.i('Finished downloading ${downloadedSongs.length}/$totalSongs playlist tracks.');
      return downloadedSongs;
    } catch (e) {
      _logger.e('Error downloading playlist: $e');
      throw Exception('Unable to download playlist. Please check the playlist URL.');
    } finally {
      yt.close();
    }
  }

  Future<Song?> _downloadDirectAudio(
    String url,
    Function(double progress, String status) onProgress,
  ) async {
    try {
      onProgress(0.10, 'Connecting to audio URL...');
      final musicDirPath = await _getMusicDirectoryPath();

      String fileName = url.split('/').last.split('?').first;
      if (fileName.isEmpty || !fileName.contains('.')) {
        fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
      } else {
        fileName = _sanitizeFileName(fileName);
      }

      final savePath = '$musicDirPath/$fileName';

      onProgress(0.20, 'Downloading audio file...');
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final p = 0.20 + (received / total) * 0.75;
            onProgress(
              p.clamp(0.0, 0.95),
              'Downloading $fileName... (${(p * 100).toInt()}%)',
            );
          } else {
            onProgress(0.50, 'Downloading $fileName...');
          }
        },
      );

      onProgress(0.98, 'Saving to Music Library...');
      final file = File(savePath);
      final title = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;

      final song = Song(
        id: savePath.hashCode.abs(),
        title: title,
        artist: 'Unknown Artist',
        album: 'Direct Downloads',
        filePath: savePath,
        duration: const Duration(minutes: 3),
        fileSize: await file.exists() ? await file.length() : 0,
        dateModified: DateTime.now(),
        genre: 'Audio Download',
        albumArtist: 'Unknown Artist',
        albumArt: null,
      );

      await _repository.addSong(song);
      onProgress(1.0, 'Download complete!');
      return song;
    } catch (e) {
      _logger.e('Error downloading direct audio link: $e');
      throw Exception('Audio download failed: $e');
    }
  }
}
