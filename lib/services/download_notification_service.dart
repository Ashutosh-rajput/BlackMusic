import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class DownloadNotificationService {
  static final DownloadNotificationService _instance = DownloadNotificationService._internal();
  factory DownloadNotificationService() => _instance;
  DownloadNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _notifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          _logger.i('Notification tapped: ${response.payload}');
        },
      );
      _isInitialized = true;
    } catch (e) {
      _logger.e('Failed to initialize DownloadNotificationService: $e');
    }
  }

  /// Show progress for single song download
  Future<void> showDownloadProgress({
    required int id,
    required String title,
    required String statusText,
    required int progress, // 0 to 100
    int maxProgress = 100,
  }) async {
    if (!_isInitialized) await init();
    try {
      final androidDetails = AndroidNotificationDetails(
        'download_channel',
        'Download Progress',
        channelDescription: 'Notifications for active music downloads',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress.clamp(0, maxProgress),
        ongoing: true,
        autoCancel: false,
      );

      await _notifications.show(
        id: id,
        title: '⬇️ Downloading: $title',
        body: '$statusText • $progress%',
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      _logger.w('Error showing download progress notification: $e');
    }
  }

  /// Show progress for playlist download
  Future<void> showPlaylistProgress({
    required int id,
    required String playlistTitle,
    required String currentSongTitle,
    required int currentTrack,
    required int totalTracks,
    required int overallProgress, // 0 to 100
  }) async {
    if (!_isInitialized) await init();
    try {
      final androidDetails = AndroidNotificationDetails(
        'download_channel',
        'Download Progress',
        channelDescription: 'Notifications for active music downloads',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: 100,
        progress: overallProgress.clamp(0, 100),
        ongoing: true,
        autoCancel: false,
      );

      await _notifications.show(
        id: id,
        title: '⬇️ Playlist: $playlistTitle',
        body: 'Song $currentTrack/$totalTracks: $currentSongTitle ($overallProgress%)',
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      _logger.w('Error showing playlist progress notification: $e');
    }
  }

  /// Show single song or playlist download completion alert
  Future<void> showDownloadCompleted({
    required int id,
    required String title,
    String? subTitle,
  }) async {
    if (!_isInitialized) await init();
    try {
      final androidDetails = const AndroidNotificationDetails(
        'download_complete_channel',
        'Download Completions',
        channelDescription: 'Notifications for completed downloads',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
      );

      await _notifications.show(
        id: id,
        title: '✅ Download Complete',
        body: subTitle ?? '$title is ready to play!',
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      _logger.w('Error showing download completed notification: $e');
    }
  }

  /// Show download failure notification
  Future<void> showDownloadFailed({
    required int id,
    required String title,
    String? errorReason,
  }) async {
    if (!_isInitialized) await init();
    try {
      final androidDetails = const AndroidNotificationDetails(
        'download_error_channel',
        'Download Errors',
        channelDescription: 'Notifications for failed downloads',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
      );

      await _notifications.show(
        id: id,
        title: '❌ Download Failed',
        body: errorReason ?? 'Failed to download $title',
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      _logger.w('Error showing download error notification: $e');
    }
  }

  /// Cancel notification by ID
  Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id: id);
    } catch (e) {
      _logger.w('Error canceling notification: $e');
    }
  }
}
