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
import 'package:pixel_player/services/settings_service.dart';

final _logger = Logger();

enum DownloadStatus { queued, downloading, completed, failed, cancelled }

class ActiveDownload {
  final String id;
  final String url;
  final String title;
  final double progress;
  final String statusMessage;
  final DownloadStatus status;
  final String? errorMessage;

  ActiveDownload({
    required this.id,
    required this.url,
    required this.title,
    required this.progress,
    required this.statusMessage,
    this.status = DownloadStatus.queued,
    this.errorMessage,
  });

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isCancelled => status == DownloadStatus.cancelled;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isQueued => status == DownloadStatus.queued;
  bool get isFailed => status == DownloadStatus.failed;

  ActiveDownload copyWith({
    String? id,
    String? url,
    String? title,
    double? progress,
    String? statusMessage,
    DownloadStatus? status,
    String? errorMessage,
  }) {
    return ActiveDownload(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DownloadService {
  final MusicRepository _repository;
  final SettingsService? _settingsService;
  final Dio _dio = Dio();
  final DownloadNotificationService _notificationService =
      DownloadNotificationService();

  /// Cancellation belongs to an individual queue entry.  Keeping this keyed by
  /// download id also makes the worker safe if the queue becomes concurrent.
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, DateTime> _lastProgressUpdate = {};
  bool _isProcessingQueue = false;

  final ValueNotifier<List<ActiveDownload>> downloadQueueNotifier =
      ValueNotifier([]);

  /// The queue is the source of truth.  Do not store a second active item,
  /// otherwise progress/status updates can get out of sync with the queue.
  ActiveDownload? get activeDownload {
    final downloads = downloadQueueNotifier.value;
    for (final download in downloads) {
      if (download.isDownloading) return download;
    }
    return null;
  }

  String _downloadId(String url) {
    final cleanUrl = _extractFirstUrl(url.trim());
    final uri = Uri.tryParse(cleanUrl);
    final host = uri?.host.toLowerCase() ?? '';
    String? videoId;
    if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
      videoId =
          uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.first : null;
    } else if (host == 'youtube.com' || host.endsWith('.youtube.com')) {
      videoId = uri?.queryParameters['v'];
      if (videoId == null &&
          uri != null &&
          uri.pathSegments.length >= 2 &&
          const {'shorts', 'embed', 'live'}.contains(uri.pathSegments.first)) {
        videoId = uri.pathSegments[1];
      }
    }
    return videoId == null || videoId.isEmpty
        ? 'url:$cleanUrl'
        : 'youtube:$videoId';
  }

  bool _isCancelled(String downloadId) {
    return downloadQueueNotifier.value.any(
      (download) => download.id == downloadId && download.isCancelled,
    );
  }

  DownloadService({
    required MusicRepository repository,
    SettingsService? settingsService,
  })  : _repository = repository,
        _settingsService = settingsService;

  ActiveDownload? getDownloadByUrl(String url) {
    final clean = _downloadId(url);
    final matches = downloadQueueNotifier.value.where((d) => d.id == clean);
    return matches.isNotEmpty ? matches.last : null;
  }

  void _updateQueuedTitle(String url, String title) {
    final queue = List<ActiveDownload>.from(downloadQueueNotifier.value);
    final index =
        queue.indexWhere((download) => download.id == _downloadId(url));
    if (index == -1 || queue[index].title == title) return;

    queue[index] = queue[index].copyWith(title: title);
    downloadQueueNotifier.value = queue;
  }

  Future<List<String>> _getPlaylistTrackUrls(String playlistUrl) async {
    final trackUrls = <String>[];
    final yt = YoutubeExplode();

    try {
      final playlistId = PlaylistId(playlistUrl).value;
      await for (final video in yt.playlists.getVideos(playlistId)) {
        trackUrls.add(video.url);
      }
    } catch (_) {}
    yt.close();

    if (trackUrls.isEmpty) {
      final htmlUrls = await _fetchPlaylistVideoUrlsHtml(playlistUrl);
      trackUrls.addAll(htmlUrls);
    }

    return trackUrls;
  }

  /// Enqueue download for background multi-track execution
  Future<void> enqueueDownload({required String url, String? title}) async {
    final cleanUrl = _extractFirstUrl(url.trim());
    if (cleanUrl.isEmpty) return;

    if (_isPlaylistUrl(cleanUrl)) {
      final tempId = _downloadId(cleanUrl);
      final currentList = List<ActiveDownload>.from(downloadQueueNotifier.value);
      if (!currentList.any((d) => d.id == tempId)) {
        currentList.add(ActiveDownload(
          id: tempId,
          url: cleanUrl,
          title: title ?? 'Parsing Playlist Tracks...',
          progress: 0.0,
          statusMessage: 'Scanning playlist...',
          status: DownloadStatus.queued,
        ));
        downloadQueueNotifier.value = currentList;
      }

      final trackUrls = await _getPlaylistTrackUrls(cleanUrl);

      // Remove temporary placeholder
      final updatedList = List<ActiveDownload>.from(downloadQueueNotifier.value);
      updatedList.removeWhere((d) => d.id == tempId);

      if (trackUrls.isNotEmpty) {
        for (int i = 0; i < trackUrls.length; i++) {
          final tUrl = trackUrls[i];
          final tId = _downloadId(tUrl);
          if (!updatedList.any((d) => d.id == tId)) {
            updatedList.add(ActiveDownload(
              id: tId,
              url: tUrl,
              title: 'Playlist Track ${i + 1} of ${trackUrls.length}',
              progress: 0.0,
              statusMessage: 'Queued...',
              status: DownloadStatus.queued,
            ));
          }
        }
        downloadQueueNotifier.value = updatedList;
        unawaited(_processQueue());
        return;
      }
    }

    final downloadId = _downloadId(cleanUrl);
    final existingList = List<ActiveDownload>.from(downloadQueueNotifier.value);
    final existingIndex = existingList.indexWhere((d) => d.id == downloadId);

    if (existingIndex != -1) {
      final existing = existingList[existingIndex];
      if (existing.isCompleted || existing.isFailed || existing.isCancelled) {
        existingList[existingIndex] = ActiveDownload(
          id: downloadId,
          url: cleanUrl,
          title: title ?? existing.title,
          progress: 0.0,
          statusMessage: 'Queued...',
          status: DownloadStatus.queued,
        );
      }
    } else {
      existingList.add(ActiveDownload(
        id: downloadId,
        url: cleanUrl,
        title: title ?? 'Audio Download',
        progress: 0.0,
        statusMessage: 'Queued...',
        status: DownloadStatus.queued,
      ));
    }

    downloadQueueNotifier.value = existingList;
    unawaited(_processQueue());
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (true) {
        try {
          final list = List<ActiveDownload>.from(downloadQueueNotifier.value);
          final nextIndex =
              list.indexWhere((d) => d.status == DownloadStatus.queued);
          if (nextIndex == -1) break;

          final target = list[nextIndex];
          list[nextIndex] = target.copyWith(
            status: DownloadStatus.downloading,
            statusMessage: 'Starting download...',
          );
          _cancelTokens[target.id] = CancelToken();
          downloadQueueNotifier.value = List.from(list);

          try {
            final result = await downloadFromUrl(
              url: target.url,
              downloadId: target.id,
              onProgress: (progress, statusMsg) {
                final now = DateTime.now();
                final last = _lastProgressUpdate[target.id];
                if (progress < 1.0 &&
                    last != null &&
                    now.difference(last) < const Duration(milliseconds: 100)) {
                  return;
                }
                _lastProgressUpdate[target.id] = now;
                final currentList =
                    List<ActiveDownload>.from(downloadQueueNotifier.value);
                final idx = currentList.indexWhere((d) => d.id == target.id);
                if (idx != -1 && !currentList[idx].isCancelled) {
                  final updated = currentList[idx].copyWith(
                    progress: progress,
                    statusMessage: statusMsg,
                    status: progress >= 1.0
                        ? DownloadStatus.completed
                        : DownloadStatus.downloading,
                  );
                  currentList[idx] = updated;
                  downloadQueueNotifier.value = currentList;
                }
              },
            );

            final endList =
                List<ActiveDownload>.from(downloadQueueNotifier.value);
            final endIdx = endList.indexWhere((d) => d.id == target.id);
            if (endIdx != -1) {
              if (endList[endIdx].isCancelled || result == null) {
                endList[endIdx] = endList[endIdx].copyWith(
                  status: DownloadStatus.cancelled,
                  statusMessage: 'Cancelled',
                );
              } else {
                endList[endIdx] = endList[endIdx].copyWith(
                  progress: 1.0,
                  statusMessage: 'Download complete!',
                  status: DownloadStatus.completed,
                );
              }
              downloadQueueNotifier.value = endList;
            }
          } catch (e) {
            final errList =
                List<ActiveDownload>.from(downloadQueueNotifier.value);
            final errIdx = errList.indexWhere((d) => d.id == target.id);
            if (errIdx != -1) {
              if (errList[errIdx].isCancelled) {
                errList[errIdx] = errList[errIdx].copyWith(
                  status: DownloadStatus.cancelled,
                  statusMessage: 'Cancelled',
                );
              } else {
                errList[errIdx] = errList[errIdx].copyWith(
                  status: DownloadStatus.failed,
                  statusMessage:
                      'Failed: ${e.toString().replaceAll("Exception: ", "")}',
                  errorMessage: e.toString(),
                );
              }
              downloadQueueNotifier.value = errList;
            }
          } finally {
            _cancelTokens.remove(target.id);
            _lastProgressUpdate.remove(target.id);
          }
        } catch (e, st) {
          // A bookkeeping/UI failure must not strand later queued downloads.
          _logger.e('Unexpected queue worker error', error: e, stackTrace: st);
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Cancel active download operation
  void cancelCurrentDownload() {
    final current = activeDownload;
    if (current != null) {
      cancelDownloadByUrl(current.url);
    }
  }

  void cancelDownloadByUrl(String url) {
    final clean = _downloadId(url);
    final list = List<ActiveDownload>.from(downloadQueueNotifier.value);
    final idx = list.indexWhere((d) => d.id == clean);
    if (idx != -1) {
      if (list[idx].status == DownloadStatus.downloading) {
        _cancelTokens[clean]?.cancel('User cancelled download');
      }
      list[idx] = list[idx].copyWith(
        status: DownloadStatus.cancelled,
        statusMessage: 'Cancelled',
      );
      downloadQueueNotifier.value = list;
    }
  }

  void clearCompletedDownloads() {
    final list = List<ActiveDownload>.from(downloadQueueNotifier.value);
    list.removeWhere((d) =>
        d.status == DownloadStatus.completed ||
        d.status == DownloadStatus.cancelled ||
        d.status == DownloadStatus.failed);
    downloadQueueNotifier.value = list;
  }

  /// Main entry point: Detects link platform and downloads high-quality audio file.
  Future<Song?> downloadFromUrl({
    required String url,
    required Function(double progress, String status) onProgress,
    String? downloadId,
  }) async {
    final cleanUrl = _extractFirstUrl(url.trim());
    if (cleanUrl.isEmpty) {
      throw Exception('Invalid or empty URL provided.');
    }

    if (_settingsService?.downloadOnlyOnWifi == true) {
      _logger.i('Download Wi-Fi only policy active.');
    }

    final id = downloadId ?? _downloadId(cleanUrl);
    if (_isPlaylistUrl(cleanUrl)) {
      final songs = await downloadPlaylist(
        url: cleanUrl,
        downloadId: id,
        onProgress: (current, total, songProgress, title) {
          final overall =
              (current > 0 ? (current - 1 + songProgress) : 0.0) / total;
          onProgress(
            overall.clamp(0.0, 1.0),
            '[$current/$total] $title',
          );
        },
      );
      return songs.isNotEmpty ? songs.first : null;
    }

    if (cleanUrl.contains('youtube.com') || cleanUrl.contains('youtu.be')) {
      return _downloadFromYoutube(cleanUrl, onProgress, id);
    } else {
      return _downloadDirectAudio(cleanUrl, onProgress, id);
    }
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
        final extDirs =
            await getExternalStorageDirectories(type: StorageDirectory.music);
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

  Future<Song?> _downloadFromYoutube(
    String url,
    Function(double progress, String status) onProgress,
    String downloadId,
  ) async {
    final cleanUrl = _extractFirstUrl(url.trim());
    final yt = YoutubeExplode();
    final notifId = cleanUrl.hashCode.abs();
    final cancelToken = _cancelTokens[downloadId];
    File? activeFile;

    try {
      onProgress(0.05, 'Parsing YouTube link...');
      final videoId = VideoId(cleanUrl).value;

      if (_isCancelled(downloadId) || (cancelToken?.isCancelled ?? false)) {
        yt.close();
        unawaited(_notificationService.cancelNotification(notifId));
        return null;
      }

      onProgress(0.10, 'Fetching video info...');
      final video = await yt.videos.get(videoId);
      final title = _sanitizeFileName(video.title);
      final artist = video.author;
      final duration = video.duration ?? Duration.zero;
      final albumArt = video.thumbnails.highResUrl;

      _updateQueuedTitle(url, video.title);

      if (_isCancelled(downloadId) || (cancelToken?.isCancelled ?? false)) {
        yt.close();
        unawaited(_notificationService.cancelNotification(notifId));
        return null;
      }

      onProgress(0.20, 'Getting stream manifest...');
      final manifest = await yt.videos.streamsClient.getManifest(videoId);

      if (_isCancelled(downloadId) || (cancelToken?.isCancelled ?? false)) {
        yt.close();
        unawaited(_notificationService.cancelNotification(notifId));
        return null;
      }

      // Select stream in order of reliability & quality:
      // 1. M4A audio-only streams
      // 2. Pre-muxed MP4 streams (100% reliable direct download)
      // 3. General audio streams (WebM fallback)
      StreamInfo? selectedStream;
      final m4aStreams = manifest.audioOnly
          .where((s) => s.container.name.toLowerCase() == 'm4a')
          .toList();
      if (m4aStreams.isNotEmpty) {
        selectedStream = m4aStreams.withHighestBitrate();
      } else if (manifest.muxed.isNotEmpty) {
        selectedStream = manifest.muxed.withHighestBitrate();
      } else if (manifest.audioOnly.isNotEmpty) {
        selectedStream = manifest.audioOnly.withHighestBitrate();
      }

      if (selectedStream == null) {
        throw Exception('No valid audio stream found for this video.');
      }

      final musicDirPath = await _getMusicDirectoryPath();
      final containerName = selectedStream.container.name.toLowerCase();
      final ext = containerName == 'mp4' ? 'm4a' : containerName;
      final savePath = '$musicDirPath/$title.$ext';
      activeFile = File(savePath);

      final totalBytes = selectedStream.size.totalBytes;
      final streamUrl = selectedStream.url.toString();

      _logger.i('[YT_DOWNLOAD 1/3] Video: "$title" ($videoId)');
      _logger.i(
          '[YT_DOWNLOAD 2/3] Stream selected: $ext, bitrate: ${selectedStream.bitrate}, totalBytes: $totalBytes');

      final existingFile = File(savePath);
      if (await existingFile.exists() && await existingFile.length() > 0) {
        _logger.i(
            '[YT_DOWNLOAD exists] Local file already exists at $savePath, creating Song model directly.');
        onProgress(1.0, 'Track already exists locally!');
        return Song(
          id: savePath.hashCode.abs(),
          title: video.title,
          artist: artist,
          album: 'YouTube Downloads',
          filePath: savePath,
          duration: duration,
          fileSize: await existingFile.length(),
          dateModified: await existingFile.lastModified(),
          genre: 'Downloaded',
          albumArtist: artist,
          albumArt: albumArt,
        );
      }

      final initialStatus = 'Downloading...';
      onProgress(0.30, initialStatus);
      unawaited(_notificationService.showDownloadProgress(
        id: notifId,
        title: video.title,
        statusText: initialStatus,
        progress: 30,
      ));

      try {
        await _dio.download(
          streamUrl,
          savePath,
          cancelToken: cancelToken,
          options: Options(
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
            },
            receiveTimeout: const Duration(seconds: 120),
            connectTimeout: const Duration(seconds: 15),
          ),
          onReceiveProgress: (received, total) {
            if (_isCancelled(downloadId) ||
                (cancelToken?.isCancelled ?? false)) {
              cancelToken?.cancel('User cancelled download');
              return;
            }
            final effectiveTotal = total > 0 ? total : totalBytes;
            if (effectiveTotal > 0) {
              final p = 0.30 + (received / effectiveTotal) * 0.65;
              final progressInt = (p * 100).toInt();
              final recMb = (received / 1024 / 1024).toStringAsFixed(1);
              final totMb = (effectiveTotal / 1024 / 1024).toStringAsFixed(1);
              final statusMsg = 'Downloading... ($progressInt%)';
              onProgress(p.clamp(0.0, 0.95), statusMsg);

              unawaited(_notificationService
                  .showDownloadProgress(
                    id: notifId,
                    title: video.title,
                    statusText: '$recMb MB / $totMb MB',
                    progress: progressInt,
                  )
                  .catchError((_) {}));
            } else {
              onProgress(
                0.50,
                'Downloading... ${(received / 1024 / 1024).toStringAsFixed(1)} MB',
              );
            }
          },
        );
      } on DioException catch (dioErr) {
        if (CancelToken.isCancel(dioErr) ||
            _isCancelled(downloadId) ||
            (cancelToken?.isCancelled ?? false)) {
          _logger.i('[YT_DOWNLOAD] Download cancelled by user.');
          unawaited(_notificationService.cancelNotification(notifId));
          if (await activeFile.exists()) {
            await activeFile.delete();
          }
          return null;
        }

        _logger.w(
            '[YT_DOWNLOAD] Dio direct download failed ($dioErr), trying YoutubeExplode streamsClient...');
        final stream = yt.videos.streamsClient.get(selectedStream);
        final sink = activeFile.openWrite();
        int downloaded = 0;

        try {
          await for (final chunk in stream) {
            if (_isCancelled(downloadId) ||
                (cancelToken?.isCancelled ?? false)) {
              break;
            }
            downloaded += chunk.length;
            sink.add(chunk);

            if (totalBytes > 0) {
              final p = 0.30 + (downloaded / totalBytes) * 0.65;
              final progressInt = (p * 100).toInt();
              final statusMsg = 'Downloading... ($progressInt%)';
              onProgress(p.clamp(0.0, 0.95), statusMsg);

              unawaited(_notificationService
                  .showDownloadProgress(
                    id: notifId,
                    title: video.title,
                    statusText: '$progressInt%',
                    progress: progressInt,
                  )
                  .catchError((_) {}));
            }
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
      }

      if (_isCancelled(downloadId) || (cancelToken?.isCancelled ?? false)) {
        _logger.i('[YT_DOWNLOAD] Cleaned up after cancellation.');
        unawaited(_notificationService.cancelNotification(notifId));
        if (await activeFile.exists()) {
          await activeFile.delete();
        }
        return null;
      }

      _logger.i('[YT_DOWNLOAD 3/3] Download finished naturally.');

      final savedLength = await activeFile.length();
      if (savedLength == 0 || (totalBytes > 0 && savedLength != totalBytes)) {
        _logger.w(
            '[YT_DOWNLOAD incomplete] Expected $totalBytes bytes, received $savedLength. Cleaning up partial file...');
        if (await activeFile.exists()) {
          await activeFile.delete();
        }
        throw Exception(
            'Incomplete download: expected $totalBytes bytes, received $savedLength');
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
      unawaited(_notificationService.cancelNotification(notifId));
      unawaited(_notificationService.showDownloadCompleted(
        id: notifId,
        title: video.title,
        subTitle: '${video.title} downloaded successfully',
      ));
      return song;
    } catch (e) {
      if (_isCancelled(downloadId) || (cancelToken?.isCancelled ?? false)) {
        return null;
      }
      if (activeFile != null && await activeFile.exists()) {
        try {
          _logger.w(
              '[YT_DOWNLOAD] Cleaning up partial download file: ${activeFile.path}');
          await activeFile.delete();
        } catch (_) {}
      }
      _logger.e('YouTube download failed: $e');
      rethrow;
    } finally {
      yt.close();
    }
  }

  bool _isPlaylistUrl(String url) {
    // YouTube Mix radios (list=RD...) are dynamic radio streams, not static playlists.
    if (url.contains('list=RD')) {
      return false;
    }
    // If it's a dedicated playlist link (youtube.com/playlist?list=...)
    if (url.contains('/playlist')) {
      return true;
    }
    // If it contains list= without a specific video v= parameter
    if (url.contains('list=') && !url.contains('v=')) {
      return true;
    }
    return false;
  }

  Future<List<String>> _fetchPlaylistVideoUrlsHtml(String playlistUrl) async {
    try {
      _logger.i('[PLAYLIST_HTML] Fetching playlist HTML via Dio...');
      final response = await _dio.get(
        playlistUrl,
        options: Options(
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
          },
          receiveTimeout: const Duration(seconds: 15),
          connectTimeout: const Duration(seconds: 10),
        ),
      );
      final html = response.data.toString();
      final matches = RegExp(r'"videoId":"([a-zA-Z0-9_-]{11})"').allMatches(html);
      final videoIds = <String>{};
      for (final match in matches) {
        final id = match.group(1);
        if (id != null && id.isNotEmpty) {
          videoIds.add(id);
        }
      }
      _logger.i(
          '[PLAYLIST_HTML] Found ${videoIds.length} unique video IDs via HTML fallback');
      return videoIds.map((id) => 'https://www.youtube.com/watch?v=$id').toList();
    } catch (e) {
      _logger.w('[PLAYLIST_HTML] HTML fallback failed: $e');
      return [];
    }
  }

  Future<List<Song>> downloadPlaylist({
    required String url,
    required String downloadId,
    required Function(int current, int total, double songProgress, String title)
        onProgress,
  }) async {
    final yt = YoutubeExplode();
    final downloadedSongs = <Song>[];
    List<String> trackUrls = [];

    try {
      onProgress(0, 1, 0.0, 'Fetching playlist details...');
      try {
        final playlistId = PlaylistId(url).value;
        final playlist = await yt.playlists.get(playlistId);

        onProgress(0, 1, 0.05, 'Loading playlist tracks...');
        await for (final video in yt.playlists.getVideos(playlist.id)) {
          trackUrls.add(video.url);
        }
      } catch (e) {
        _logger.w('[PLAYLIST_DOWNLOAD] YoutubeExplode playlist stream notice: $e');
      }

      // HTML Fallback via Dio regex if YoutubeExplode yielded 0 videos or failed
      if (trackUrls.isEmpty) {
        onProgress(0, 1, 0.05, 'Scanning playlist HTML...');
        trackUrls = await _fetchPlaylistVideoUrlsHtml(url);
      }

      // Single Video Fallback if URL contains a video ID
      if (trackUrls.isEmpty) {
        try {
          final videoId = VideoId(url).value;
          trackUrls.add('https://www.youtube.com/watch?v=$videoId');
        } catch (_) {}
      }

      if (trackUrls.isEmpty) {
        yt.close();
        throw Exception('No videos found in this playlist.');
      }

      final totalSongs = trackUrls.length;
      _logger.i(
          '[PLAYLIST_DOWNLOAD] Enqueuing $totalSongs tracks from playlist');

      for (int i = 0; i < trackUrls.length; i++) {
        if (_isCancelled(downloadId)) {
          _logger.i('[PLAYLIST_DOWNLOAD] Playlist download cancelled.');
          break;
        }

        final videoUrl = trackUrls[i];
        final trackNumber = i + 1;

        onProgress(trackNumber, totalSongs, 0.05,
            'Track $trackNumber of $totalSongs');

        try {
          final song =
              await _downloadFromYoutube(videoUrl, (progress, status) {
            onProgress(trackNumber, totalSongs, progress, status);
          }, downloadId);
          if (song != null) {
            downloadedSongs.add(song);
          }
        } catch (e) {
          _logger.w(
              '[PLAYLIST_DOWNLOAD] Error downloading track $trackNumber ($videoUrl): $e');
        }
      }

      yt.close();
      return downloadedSongs;
    } catch (e) {
      _logger.e('Playlist download error: $e');
      yt.close();
      rethrow;
    }
  }

  Future<Song?> _downloadDirectAudio(
    String url,
    Function(double progress, String status) onProgress,
    String downloadId,
  ) async {
    final cancelToken = _cancelTokens.putIfAbsent(downloadId, CancelToken.new);

    try {
      final musicDir = await _getMusicDirectoryPath();
      final fileName = url.split('/').last.split('?').first;
      final sanitizedFileName =
          _sanitizeFileName(fileName.isEmpty ? 'audio_track.mp3' : fileName);
      final savePath = '$musicDir/$sanitizedFileName';

      onProgress(0.20, 'Downloading audio file...');

      await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final p = (received / total);
            onProgress(
              p,
              'Downloading $fileName... (${(p * 100).toInt()}%)',
            );
          } else {
            onProgress(0.50, 'Downloading $fileName...');
          }
        },
      );

      final file = File(savePath);
      final length = await file.length();
      final titleWithoutExt =
          sanitizedFileName.replaceAll(RegExp(r'\.[^.]+$'), '');

      final song = Song(
        id: savePath.hashCode.abs(),
        title: titleWithoutExt,
        artist: 'Unknown Artist',
        album: 'Direct Downloads',
        filePath: savePath,
        duration: const Duration(minutes: 3),
        fileSize: length,
        dateModified: DateTime.now(),
        genre: 'Audio Download',
        albumArtist: 'Unknown Artist',
      );

      await _repository.addSong(song);
      onProgress(1.0, 'Download complete!');
      return song;
    } catch (e) {
      _logger.e('Direct download error: $e');
      rethrow;
    }
  }
}
