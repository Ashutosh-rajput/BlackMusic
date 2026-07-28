import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:logger/logger.dart';

import 'package:flutter/foundation.dart';
import 'package:pixel_player/services/download_notification_service.dart';

final _logger = Logger();

class ActiveDownload {
  final String id;
  final String url;
  final String title;
  final double progress;
  final String statusMessage;
  final bool isCompleted;
  final bool isCancelled;
  final String? errorMessage;

  ActiveDownload({
    required this.id,
    required this.url,
    required this.title,
    required this.progress,
    required this.statusMessage,
    this.isCompleted = false,
    this.isCancelled = false,
    this.errorMessage,
  });

  ActiveDownload copyWith({
    String? id,
    String? url,
    String? title,
    double? progress,
    String? statusMessage,
    bool? isCompleted,
    bool? isCancelled,
    String? errorMessage,
  }) {
    return ActiveDownload(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      isCompleted: isCompleted ?? this.isCompleted,
      isCancelled: isCancelled ?? this.isCancelled,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DownloadService {
  final MusicRepository _repository;
  final Dio _dio = Dio();
  final DownloadNotificationService _notificationService = DownloadNotificationService();

  CancelToken? _cancelToken;
  bool _isCanceled = false;

  final ValueNotifier<ActiveDownload?> activeDownloadNotifier = ValueNotifier(null);

  DownloadService(this._repository);

  /// Cancel active download operation
  void cancelCurrentDownload() {
    _isCanceled = true;
    _cancelToken?.cancel("User cancelled download");
    final current = activeDownloadNotifier.value;
    if (current != null) {
      activeDownloadNotifier.value = current.copyWith(
        isCancelled: true,
        statusMessage: 'Download cancelled by user',
      );
    }
  }

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
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final target = Directory('${downloadsDir.path}/blackmusic');
          if (!await target.exists()) {
            await target.create(recursive: true);
          }
          return target.path;
        }
      } catch (e) {
        _logger.w('getDownloadsDirectory fallback: $e');
      }
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
    final appDir = await getApplicationDocumentsDirectory();
    final target = Directory('${appDir.path}/blackmusic');
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target.path;
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
        final notifId = videoId.hashCode.abs();
        _cancelToken = CancelToken();
        _isCanceled = false;

        _logger.i('[YT_DOWNLOAD 1/3] Video: "$title" ($videoId)');
        _logger.i('[YT_DOWNLOAD 2/3] Stream selected: $ext, bitrate: ${selectedStream.bitrate}, totalBytes: $totalBytes');
        assert(() {
          _logger.i('[YT_DOWNLOAD URL] Stream Direct Link: $streamUrl');
          return true;
        }());

        final initialStatus = 'Downloading "${video.title}"...';
        onProgress(0.30, initialStatus);
        activeDownloadNotifier.value = ActiveDownload(
          id: videoId,
          url: cleanUrl,
          title: video.title,
          progress: 0.30,
          statusMessage: initialStatus,
        );

        // Try Dio direct stream download first, fallback to YoutubeExplode streamsClient
        try {
          await _dio.download(
            streamUrl.toString(),
            savePath,
            cancelToken: _cancelToken,
            options: Options(
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
              },
              receiveTimeout: const Duration(seconds: 120),
              connectTimeout: const Duration(seconds: 15),
            ),
            onReceiveProgress: (received, total) {
              if (_isCanceled) return;
              final effectiveTotal = total > 0 ? total : totalBytes;
              if (effectiveTotal > 0) {
                final p = 0.30 + (received / effectiveTotal) * 0.65;
                final progressInt = (p * 100).toInt();
                final recMb = (received / 1024 / 1024).toStringAsFixed(1);
                final totMb = (effectiveTotal / 1024 / 1024).toStringAsFixed(1);
                final statusMsg = 'Downloading "${video.title}"... ($progressInt%)';
                onProgress(
                  p.clamp(0.0, 0.95),
                  statusMsg,
                );
                activeDownloadNotifier.value = ActiveDownload(
                  id: videoId,
                  url: cleanUrl,
                  title: video.title,
                  progress: p.clamp(0.0, 0.95),
                  statusMessage: statusMsg,
                );
                _notificationService.showDownloadProgress(
                  id: notifId,
                  title: video.title,
                  statusText: '$recMb MB / $totMb MB',
                  progress: progressInt,
                );
              } else {
                onProgress(
                  0.50,
                  'Downloading "${video.title}"... ${(received / 1024 / 1024).toStringAsFixed(1)} MB',
                );
              }
            },
          );
        } on DioException catch (dioErr) {
          if (CancelToken.isCancel(dioErr) || _isCanceled) {
            _logger.i('[YT_DOWNLOAD] Download cancelled by user.');
            await _notificationService.cancelNotification(notifId);
            if (await activeFile.exists()) {
              await activeFile.delete();
            }
            return null;
          }
          _logger.w('[YT_DOWNLOAD] Dio direct download failed ($dioErr), trying YoutubeExplode streamsClient...');
          final stream = yt.videos.streamsClient.get(selectedStream);
          final sink = activeFile.openWrite();
          int downloaded = 0;

          try {
            await for (final chunk in stream) {
              if (_isCanceled) break;
              downloaded += chunk.length;
              sink.add(chunk);

              if (totalBytes > 0) {
                final p = 0.30 + (downloaded / totalBytes) * 0.65;
                final progressInt = (p * 100).toInt();
                final statusMsg = 'Downloading "${video.title}"... ($progressInt%)';
                onProgress(
                  p.clamp(0.0, 0.95),
                  statusMsg,
                );
                activeDownloadNotifier.value = ActiveDownload(
                  id: videoId,
                  url: cleanUrl,
                  title: video.title,
                  progress: p.clamp(0.0, 0.95),
                  statusMessage: statusMsg,
                );
                _notificationService.showDownloadProgress(
                  id: notifId,
                  title: video.title,
                  statusText: '$progressInt%',
                  progress: progressInt,
                );
              }
            }
          } finally {
            await sink.flush();
            await sink.close();
          }
        }

        if (_isCanceled) {
          _logger.i('[YT_DOWNLOAD] Cleaned up after cancellation.');
          await _notificationService.cancelNotification(notifId);
          if (await activeFile.exists()) {
            await activeFile.delete();
          }
          return null;
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
        activeDownloadNotifier.value = ActiveDownload(
          id: videoId,
          url: cleanUrl,
          title: video.title,
          progress: 1.0,
          statusMessage: 'Download complete!',
          isCompleted: true,
        );
        await _notificationService.cancelNotification(notifId);
        await _notificationService.showDownloadCompleted(
          id: notifId,
          title: video.title,
          subTitle: '${video.title} downloaded successfully',
        );
        return song;
      }
      throw Exception('No valid audio stream found for this video.');
    } catch (e) {
      if (_isCanceled) {
        return null;
      }
      if (activeFile != null && await activeFile.exists()) {
        try {
          _logger.w('[YT_DOWNLOAD] Cleaning up partial download file: ${activeFile.path}');
          await activeFile.delete();
        } catch (_) {}
      }
      _logger.e('YouTube download failed: $e');
      activeDownloadNotifier.value = ActiveDownload(
        id: cleanUrl,
        url: cleanUrl,
        title: 'Song Download',
        progress: 0.0,
        statusMessage: 'Failed to download track',
        errorMessage: e.toString(),
      );
      _notificationService.showDownloadFailed(
        id: cleanUrl.hashCode.abs(),
        title: 'Song Download',
        errorReason: 'Failed to download track',
      );
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
      final playlistNotifId = playlist.id.hashCode.abs();

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
          final videoIds = <String>{};
          for (final match in matches) {
            final id = match.group(1);
            if (id != null) videoIds.add(id);
          }
          for (final id in videoIds) {
            videoUrls.add('https://www.youtube.com/watch?v=$id');
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
        final overallPercent = ((index / totalSongs) * 100).toInt();

        try {
          final song = await _downloadYoutube(
            videoUrl,
            (songProgress, status) {
              onProgress(index, totalSongs, songProgress, status);
              _notificationService.showPlaylistProgress(
                id: playlistNotifId,
                playlistTitle: playlist.title,
                currentSongTitle: status,
                currentTrack: index,
                totalTracks: totalSongs,
                overallProgress: overallPercent,
              );
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
      await _notificationService.cancelNotification(playlistNotifId);
      await _notificationService.showDownloadCompleted(
        id: playlistNotifId,
        title: playlist.title,
        subTitle: 'Downloaded ${downloadedSongs.length}/$totalSongs tracks',
      );
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
