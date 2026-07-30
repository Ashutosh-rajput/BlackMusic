import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/models/playlist_model.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:logger/logger.dart';

import 'package:flutter/foundation.dart';
import 'package:pixel_player/core/utils/hash_utils.dart';
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
  final int? targetPlaylistId;

  /// True when this download originated from the OS share sheet rather than
  /// a manually pasted link. Used to gate auto-add-to-library behavior.
  final bool fromShare;

  /// True when the file has finished downloading but is waiting for the user
  /// to explicitly accept it into the library (see [SettingsService.autoAddSharedSongs]).
  final bool pendingLibraryAcceptance;

  /// The downloaded song, kept around so a pending shared download can be
  /// accepted (or discarded) later without re-downloading.
  final Song? resultSong;

  ActiveDownload({
    required this.id,
    required this.url,
    required this.title,
    required this.progress,
    required this.statusMessage,
    this.status = DownloadStatus.queued,
    this.errorMessage,
    this.targetPlaylistId,
    this.fromShare = false,
    this.pendingLibraryAcceptance = false,
    this.resultSong,
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
    int? targetPlaylistId,
    bool? fromShare,
    bool? pendingLibraryAcceptance,
    Song? resultSong,
  }) {
    return ActiveDownload(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      targetPlaylistId: targetPlaylistId ?? this.targetPlaylistId,
      fromShare: fromShare ?? this.fromShare,
      pendingLibraryAcceptance: pendingLibraryAcceptance ?? this.pendingLibraryAcceptance,
      resultSong: resultSong ?? this.resultSong,
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

  /// Enqueue download for background multi-track execution.
  /// [fromShare] marks downloads that arrived via the OS share sheet, which
  /// are subject to [SettingsService.autoAddSharedSongs] before being added
  /// to the library.
  Future<void> enqueueDownload({
    required String url,
    String? title,
    bool fromShare = false,
  }) async {
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
          fromShare: fromShare,
        ));
        downloadQueueNotifier.value = currentList;
      }

      String pName = title ?? 'Shared Playlist';
      final yt = YoutubeExplode();
      try {
        final playlistId = PlaylistId(cleanUrl).value;
        final playlist = await yt.playlists.get(playlistId);
        if (playlist.title.trim().isNotEmpty) {
          pName = playlist.title.trim();
        }
      } catch (e) {
        _logger.w('[PLAYLIST_SHARE] Failed fetching playlist title: $e');
      } finally {
        yt.close();
      }

      // FIRST STEP: Create playlist immediately in database/repository
      PlaylistModel? autoPlaylist;
      try {
        final existingPlaylists = await _repository.getPlaylists();
        final match = existingPlaylists.where(
            (p) => p.name.trim().toLowerCase() == pName.trim().toLowerCase());
        if (match.isNotEmpty) {
          autoPlaylist = match.first;
        } else {
          autoPlaylist = await _repository.createPlaylist(
              pName, 'Auto-created from shared playlist');
        }
      } catch (e) {
        _logger.w('[PLAYLIST_SHARE] Failed to auto-create playlist "$pName": $e');
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
              title: '${autoPlaylist?.name ?? pName} - Track ${i + 1}/${trackUrls.length}',
              progress: 0.0,
              statusMessage: 'Queued...',
              status: DownloadStatus.queued,
              targetPlaylistId: autoPlaylist?.id,
              fromShare: fromShare,
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
          fromShare: fromShare,
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
        fromShare: fromShare,
      ));
    }

    downloadQueueNotifier.value = existingList;
    unawaited(_processQueue());
  }

  /// Builds the completed [ActiveDownload] state for a successful download,
  /// either finalizing it into the library/playlist (when [autoAddToLibrary]
  /// is true) or parking it as [ActiveDownload.pendingLibraryAcceptance] so
  /// the user can accept/discard it later via [acceptSharedDownload] /
  /// [discardSharedDownload].
  Future<ActiveDownload> _finalizeCompletedDownload(
    ActiveDownload item,
    Song result,
    bool autoAddToLibrary,
  ) async {
    if (!autoAddToLibrary) {
      return item.copyWith(
        progress: 1.0,
        statusMessage: 'Downloaded — review to add to library',
        status: DownloadStatus.completed,
        pendingLibraryAcceptance: true,
        resultSong: result,
      );
    }

    if (item.targetPlaylistId != null) {
      try {
        await _repository.addSongToPlaylist(item.targetPlaylistId!, result);
        _logger.i('[PLAYLIST_SHARE] Added "${result.title}" to target playlist ID ${item.targetPlaylistId}');
      } catch (err) {
        _logger.w('[PLAYLIST_SHARE] Error adding song to target playlist: $err');
      }
    }
    return item.copyWith(
      progress: 1.0,
      statusMessage: 'Download complete!',
      status: DownloadStatus.completed,
    );
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

          final autoAddToLibrary = !target.fromShare ||
              (_settingsService?.autoAddSharedSongs ?? true);

          try {
            final result = await downloadFromUrl(
              url: target.url,
              downloadId: target.id,
              addToLibrary: autoAddToLibrary,
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
                endList[endIdx] = await _finalizeCompletedDownload(
                  endList[endIdx],
                  result,
                  autoAddToLibrary,
                );
              }
              downloadQueueNotifier.value = endList;
            }
          } catch (e) {
            final shouldRetry = (_settingsService?.retryFailedDownloads ?? false) &&
                !_isCancelled(target.id);
            bool retriedSuccess = false;
            if (shouldRetry) {
              _logger.i('Retrying failed download for ${target.title}...');
              try {
                final resultRetry = await downloadFromUrl(
                  url: target.url,
                  downloadId: target.id,
                  addToLibrary: autoAddToLibrary,
                  onProgress: (progress, statusMsg) {},
                );
                if (resultRetry != null) {
                  retriedSuccess = true;
                  final endList = List<ActiveDownload>.from(downloadQueueNotifier.value);
                  final endIdx = endList.indexWhere((d) => d.id == target.id);
                  if (endIdx != -1) {
                    endList[endIdx] = await _finalizeCompletedDownload(
                      endList[endIdx],
                      resultRetry,
                      autoAddToLibrary,
                    );
                    downloadQueueNotifier.value = endList;
                  }
                }
              } catch (_) {}
            }

            if (!retriedSuccess) {
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
        (d.status == DownloadStatus.completed && !d.pendingLibraryAcceptance) ||
        d.status == DownloadStatus.cancelled ||
        d.status == DownloadStatus.failed);
    downloadQueueNotifier.value = list;
  }

  /// Adds a previously downloaded shared song into the library (and its
  /// target playlist, if any) once the user has explicitly accepted it.
  Future<void> acceptSharedDownload(String downloadId) async {
    final list = List<ActiveDownload>.from(downloadQueueNotifier.value);
    final idx = list.indexWhere((d) => d.id == downloadId);
    if (idx == -1) return;

    final item = list[idx];
    final song = item.resultSong;
    if (song == null || !item.pendingLibraryAcceptance) return;

    try {
      await _repository.addSong(song);
      if (item.targetPlaylistId != null) {
        try {
          await _repository.addSongToPlaylist(item.targetPlaylistId!, song);
        } catch (e) {
          _logger.w('[SHARE_ACCEPT] Error adding accepted song to target playlist: $e');
        }
      }
      list[idx] = item.copyWith(
        pendingLibraryAcceptance: false,
        statusMessage: 'Added to library',
      );
      downloadQueueNotifier.value = list;
    } catch (e) {
      _logger.e('[SHARE_ACCEPT] Failed to add accepted song to library: $e');
    }
  }

  /// Discards a previously downloaded shared song: deletes the downloaded
  /// file and removes it from the queue without adding it to the library.
  Future<void> discardSharedDownload(String downloadId) async {
    final list = List<ActiveDownload>.from(downloadQueueNotifier.value);
    final idx = list.indexWhere((d) => d.id == downloadId);
    if (idx == -1) return;

    final song = list[idx].resultSong;
    if (song != null) {
      try {
        final file = File(song.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        _logger.w('[SHARE_ACCEPT] Failed to delete discarded download file: $e');
      }
    }

    list.removeAt(idx);
    downloadQueueNotifier.value = list;
  }

  /// Cancel all queued and active downloads at once
  void cancelAllDownloads() {
    final list = List<ActiveDownload>.from(downloadQueueNotifier.value);
    for (var i = 0; i < list.length; i++) {
      final d = list[i];
      if (d.status == DownloadStatus.queued || d.status == DownloadStatus.downloading) {
        if (d.status == DownloadStatus.downloading) {
          _cancelTokens[d.id]?.cancel('User cancelled all downloads');
        }
        list[i] = d.copyWith(
          status: DownloadStatus.cancelled,
          statusMessage: 'Cancelled',
        );
      }
    }
    downloadQueueNotifier.value = list;
  }

  /// Main entry point: Detects link platform and downloads high-quality audio file.
  /// When [addToLibrary] is false the file is still downloaded to disk and the
  /// returned [Song] is populated, but it is not persisted to the repository —
  /// used for shared downloads awaiting explicit user acceptance.
  Future<Song?> downloadFromUrl({
    required String url,
    required Function(double progress, String status) onProgress,
    String? downloadId,
    bool addToLibrary = true,
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
      return _downloadFromYoutube(cleanUrl, onProgress, id, addToLibrary: addToLibrary);
    } else {
      return _downloadDirectAudio(cleanUrl, onProgress, id, addToLibrary: addToLibrary);
    }
  }

  String _extractFirstUrl(String text) {
    final regex = RegExp(r'https?://[^\s]+');
    final match = regex.firstMatch(text);
    return match?.group(0) ?? text;
  }

  Future<String> _getMusicDirectoryPath() async {
    if (Platform.isAndroid) {
      // 1. Try public shared Downloads folder (/storage/emulated/0/Download/blackmusic)
      try {
        final publicDownloadDir =
            Directory('/storage/emulated/0/Download/blackmusic');
        if (!await publicDownloadDir.exists()) {
          await publicDownloadDir.create(recursive: true);
        }
        return publicDownloadDir.path;
      } catch (e) {
        _logger.w('Failed creating public Download/blackmusic dir: $e');
      }

      // 2. Fallback to Android External Storage root / Download / blackmusic
      try {
        final extStorageDir = await getExternalStorageDirectory();
        if (extStorageDir != null) {
          final pathSegments = extStorageDir.path.split('/');
          final androidIndex = pathSegments.indexOf('Android');
          if (androidIndex > 0) {
            final rootPath = pathSegments.sublist(0, androidIndex).join('/');
            final target = Directory('$rootPath/Download/blackmusic');
            if (!await target.exists()) {
              await target.create(recursive: true);
            }
            return target.path;
          }
        }
      } catch (e) {
        _logger.w('Failed external storage root fallback: $e');
      }
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
    String downloadId, {
    bool addToLibrary = true,
  }) async {
    final cleanUrl = _extractFirstUrl(url.trim());
    final yt = YoutubeExplode();
    final notifId = generateStableId(cleanUrl);
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

      final video = await yt.videos.get(videoId);
      final title = _sanitizeFileName(video.title);
      final artist = video.author.isNotEmpty ? video.author : 'YouTube';
      final duration = video.duration ?? Duration.zero;
      final albumArt = video.thumbnails.highResUrl;

      _updateQueuedTitle(url, video.title);

      if (_isCancelled(downloadId) || (cancelToken?.isCancelled ?? false)) {
        yt.close();
        unawaited(_notificationService.cancelNotification(notifId));
        return null;
      }

      onProgress(0.20, 'Getting stream manifest...');
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.androidVr,
        ],
      );

      for (final s in manifest.audioOnly) {
        _logger.i(
            "AUDIO -> itag=${s.tag} "
            "container=${s.container.name} "
            "mime=${s.codec.mimeType} "
            "bitrate=${s.bitrate}");
      }

      for (final s in manifest.muxed) {
        _logger.i(
            "MUXED -> itag=${s.tag} "
            "container=${s.container.name} "
            "mime=${s.codec.mimeType} "
            "bitrate=${s.bitrate}");
      }

      if (_isCancelled(downloadId) || (cancelToken?.isCancelled ?? false)) {
        yt.close();
        unawaited(_notificationService.cancelNotification(notifId));
        return null;
      }

      // Respect User Setting for Download Format: 'M4A' vs 'WebM'
      final userFormat = _settingsService?.downloadFormat ?? 'M4A';

      final m4aStreams = manifest.audioOnly.where((s) {
        final c = s.container.name.toLowerCase();
        final m = s.codec.mimeType.toLowerCase();
        return c == 'mp4' || c == 'm4a' || m.contains('audio/mp4');
      }).toList();

      final webmStreams = manifest.audioOnly.where((s) {
        final c = s.container.name.toLowerCase();
        final m = s.codec.mimeType.toLowerCase();
        return c == 'webm' || m.contains('audio/webm');
      }).toList();

      StreamInfo? selectedStream;

      if (userFormat == 'WebM') {
        if (webmStreams.isNotEmpty) {
          selectedStream = webmStreams.withHighestBitrate();
        } else if (m4aStreams.isNotEmpty) {
          selectedStream = m4aStreams.withHighestBitrate();
        }
      } else {
        // Default: M4A preferred
        if (m4aStreams.isNotEmpty) {
          selectedStream = m4aStreams.withHighestBitrate();
        } else if (webmStreams.isNotEmpty) {
          selectedStream = webmStreams.withHighestBitrate();
        }
      }

      if (selectedStream == null) {
        if (manifest.audioOnly.isNotEmpty) {
          selectedStream = manifest.audioOnly.withHighestBitrate();
        } else if (manifest.muxed.isNotEmpty) {
          selectedStream = manifest.muxed.withHighestBitrate();
        }
      }

      if (selectedStream == null) {
        throw Exception('No valid audio or video stream found for this video.');
      }

      _logger.i("Selected Type     : ${selectedStream.runtimeType}");
      _logger.i("Selected Tag      : ${selectedStream.tag}");
      _logger.i("Selected Mime     : ${selectedStream.codec.mimeType}");
      _logger.i("Selected Container: ${selectedStream.container.name}");

      final musicDirPath = await _getMusicDirectoryPath();
      final containerName = selectedStream.container.name.toLowerCase();
      final ext = (containerName == 'mp4' || containerName == 'm4a')
          ? 'm4a'
          : containerName;
      final savePath = '$musicDirPath/$title.$ext';
      activeFile = File(savePath);

      final totalBytes = selectedStream.size.totalBytes;
      final streamUrl = selectedStream.url.toString();
      _logger.i(streamUrl);

      _logger.i('[YT_DOWNLOAD 1/3] Video: "$title" ($videoId)');
      _logger.i(
          '[YT_DOWNLOAD 2/3] Stream selected: $ext, bitrate: ${selectedStream.bitrate}, totalBytes: $totalBytes');

      final existingFile = File(savePath);
      if (await existingFile.exists() && await existingFile.length() > 0) {
        _logger.i(
            '[YT_DOWNLOAD exists] Local file already exists at $savePath, creating Song model directly.');
        onProgress(1.0, 'Track already exists locally!');
        return Song(
          id: generateStableId(savePath),
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

      // Primary Downloader Engine: YoutubeExplode streamsClient.get()
      StreamInfo downloadedStream = selectedStream;
      bool downloadSuccess = false;
      try {
        _logger.i(
            '[YT_DOWNLOAD] Starting primary download via streamsClient.get()...');
        downloadSuccess = await _downloadChunkStream(
          yt: yt,
          streamInfo: selectedStream,
          saveFile: activeFile,
          downloadId: downloadId,
          cancelToken: cancelToken,
          notifId: notifId,
          videoTitle: video.title,
          onProgress: onProgress,
        );
      } catch (e, st) {
        _logger.w('[YT_DOWNLOAD] Primary streamsClient download failed: $e',
            error: e, stackTrace: st);
        downloadSuccess = false;
      }

      // Secondary Fallback: Try muxed stream via streamsClient if primary failed
      if (!downloadSuccess &&
          !_isCancelled(downloadId) &&
          !(cancelToken?.isCancelled ?? false) &&
          manifest.muxed.isNotEmpty &&
          selectedStream is! MuxedStreamInfo) {
        if (await activeFile.exists()) {
          await activeFile.delete();
        }
        final muxedStream = manifest.muxed.withHighestBitrate();
        downloadedStream = muxedStream;
        _logger.i(
            '[YT_DOWNLOAD] Fallback: Trying muxed stream via streamsClient.get()...');
        try {
          downloadSuccess = await _downloadChunkStream(
            yt: yt,
            streamInfo: muxedStream,
            saveFile: activeFile,
            downloadId: downloadId,
            cancelToken: cancelToken,
            notifId: notifId,
            videoTitle: video.title,
            onProgress: onProgress,
          );
        } catch (e, st) {
          _logger.w('[YT_DOWNLOAD] Muxed streamsClient download failed: $e',
              error: e, stackTrace: st);
          downloadSuccess = false;
        }
      }

      // Last Resort Fallback: Dio.download()
      if (!downloadSuccess &&
          !_isCancelled(downloadId) &&
          !(cancelToken?.isCancelled ?? false)) {
        if (await activeFile.exists()) {
          await activeFile.delete();
        }
        _logger.w('[YT_DOWNLOAD] Last resort fallback: Trying Dio download...');
        try {
          final fallbackUrl = downloadedStream.url.toString();
          final fallbackBytes = downloadedStream.size.totalBytes;
          await _dio.download(
            fallbackUrl,
            savePath,
            cancelToken: cancelToken,
            options: Options(
              headers: const {
                'User-Agent':
                    'com.google.android.youtube/20.10.38 (Linux; U; Android 14)',
                'Referer': 'https://www.youtube.com/',
                'Origin': 'https://www.youtube.com',
                'Accept': '*/*',
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
              final effectiveTotal = total > 0 ? total : fallbackBytes;
              if (effectiveTotal > 0) {
                final p = 0.30 + (received / effectiveTotal) * 0.65;
                final progressInt = (p * 100).toInt();
                final recMb = (received / 1024 / 1024).toStringAsFixed(1);
                final totMb = (effectiveTotal / 1024 / 1024).toStringAsFixed(1);
                onProgress(p.clamp(0.0, 0.95), 'Downloading... ($progressInt%)');

                unawaited(_notificationService
                    .showDownloadProgress(
                      id: notifId,
                      title: video.title,
                      statusText: '$recMb MB / $totMb MB ($progressInt%)',
                      progress: progressInt,
                    )
                    .catchError((_) {}));
              }
            },
          );
          downloadSuccess = true;
        } catch (dioErr) {
          _logger.e('[YT_DOWNLOAD] Last resort Dio download failed: $dioErr');
          downloadSuccess = false;
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
      final expectedBytes = downloadedStream.size.totalBytes;
      if (savedLength == 0 ||
          (expectedBytes > 0 && savedLength != expectedBytes)) {
        _logger.w(
            '[YT_DOWNLOAD incomplete] Expected $expectedBytes bytes, received $savedLength. Cleaning up partial file...');
        if (await activeFile.exists()) {
          await activeFile.delete();
        }
        throw Exception(
            'Incomplete download: expected $expectedBytes bytes, received $savedLength');
      }

      onProgress(0.98, 'Saving to Music Library...');
      final song = Song(
        id: generateStableId(savePath),
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

      if (addToLibrary) {
        await _repository.addSong(song);
      }
      onProgress(1.0, 'Download complete!');
      unawaited(_notificationService.cancelNotification(notifId));
      unawaited(_notificationService.showDownloadCompleted(
        id: notifId,
        title: video.title,
        subTitle: addToLibrary
            ? '${video.title} downloaded successfully'
            : '${video.title} downloaded — open BlackMusic to add it to your library',
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
    String? playlistTitle;

    try {
      onProgress(0, 1, 0.0, 'Fetching playlist details...');
      try {
        final playlistId = PlaylistId(url).value;
        final playlist = await yt.playlists.get(playlistId);
        if (playlist.title.trim().isNotEmpty) {
          playlistTitle = playlist.title.trim();
        }

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

      // Auto-create local playlist in app database
      final pName = (playlistTitle != null && playlistTitle.isNotEmpty)
          ? playlistTitle
          : 'Shared Playlist ${DateTime.now().day}/${DateTime.now().month}';
      
      PlaylistModel? autoPlaylist;
      try {
        final existingPlaylists = await _repository.getPlaylists();
        final match = existingPlaylists.where(
            (p) => p.name.trim().toLowerCase() == pName.toLowerCase());
        if (match.isNotEmpty) {
          autoPlaylist = match.first;
        } else {
          autoPlaylist = await _repository.createPlaylist(
              pName, 'Auto-created from shared playlist');
        }
      } catch (e) {
        _logger.w('[PLAYLIST_DOWNLOAD] Failed to auto-create playlist "$pName": $e');
      }

      final totalSongs = trackUrls.length;
      _logger.i(
          '[PLAYLIST_DOWNLOAD] Enqueuing $totalSongs tracks from playlist "${autoPlaylist?.name ?? pName}"');

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
            if (autoPlaylist != null) {
              try {
                await _repository.addSongToPlaylist(autoPlaylist.id, song);
                _logger.i('[PLAYLIST_DOWNLOAD] Added "${song.title}" to playlist "${autoPlaylist.name}"');
              } catch (e) {
                _logger.w('[PLAYLIST_DOWNLOAD] Error adding song to playlist: $e');
              }
            }
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
    String downloadId, {
    bool addToLibrary = true,
  }) async {
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
        id: generateStableId(savePath),
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

      if (addToLibrary) {
        await _repository.addSong(song);
      }
      onProgress(1.0, 'Download complete!');
      return song;
    } catch (e) {
      _logger.e('Direct download error: $e');
      rethrow;
    }
  }

  Future<bool> _downloadChunkStream({
    required YoutubeExplode yt,
    required StreamInfo streamInfo,
    required File saveFile,
    required String downloadId,
    required CancelToken? cancelToken,
    required int notifId,
    required String videoTitle,
    required Function(double progress, String status) onProgress,
  }) async {
    final totalBytes = streamInfo.size.totalBytes;
    final stream = yt.videos.streamsClient.get(streamInfo);
    final sink = saveFile.openWrite();
    int downloaded = 0;

    try {
      await for (final chunk in stream) {
        if (_isCancelled(downloadId) || (cancelToken?.isCancelled ?? false)) {
          await sink.flush();
          await sink.close();
          if (await saveFile.exists()) {
            await saveFile.delete();
          }
          return false;
        }
        downloaded += chunk.length;
        sink.add(chunk);

        if (totalBytes > 0) {
          final p = 0.30 + (downloaded / totalBytes) * 0.65;
          final progressInt = (p * 100).toInt();
          final recMb = (downloaded / 1024 / 1024).toStringAsFixed(1);
          final totMb = (totalBytes / 1024 / 1024).toStringAsFixed(1);
          onProgress(p.clamp(0.0, 0.95), 'Downloading... ($progressInt%)');

          unawaited(_notificationService
              .showDownloadProgress(
                id: notifId,
                title: videoTitle,
                statusText: '$recMb MB / $totMb MB ($progressInt%)',
                progress: progressInt,
              )
              .catchError((_) {}));
        }
      }
      await sink.flush();
      await sink.close();
      return await saveFile.exists() && await saveFile.length() > 0;
    } catch (e, st) {
      _logger.e(
        '[YT_STREAM_DOWNLOAD] Error chunk streaming: $e',
        error: e,
        stackTrace: st,
      );
      try {
        await sink.flush();
        await sink.close();
      } catch (_) {}
      return false;
    }
  }
}
