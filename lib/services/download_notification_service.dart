import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class DownloadNotificationService {
  static final DownloadNotificationService _instance = DownloadNotificationService._internal();
  factory DownloadNotificationService() => _instance;
  DownloadNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const Color _primaryPurple = Color(0xFF6C5CE7);
  static const Color _successGreen = Color(0xFF00B894);
  static const Color _errorRed = Color(0xFFFF7675);

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

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      _logger.e('Failed to initialize DownloadNotificationService: $e');
    }
  }

  /// Show progress for single song download with rich layout & styling
  Future<void> showDownloadProgress({
    required int id,
    required String title,
    required String statusText,
    required int progress, // 0 to 100
    int maxProgress = 100,
  }) async {
    if (!_isInitialized) await init();
    try {
      final safeProgress = progress.clamp(0, maxProgress);

      final androidDetails = AndroidNotificationDetails(
        'download_channel',
        'Active Downloads',
        channelDescription:
            'Live progress notifications for active music downloads',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: maxProgress,
        progress: safeProgress,
        ongoing: true,
        autoCancel: false,
        color: _primaryPurple,
        subText: 'BlackMusic',
        category: AndroidNotificationCategory.progress,
        styleInformation: BigTextStyleInformation(
          '$statusText • $safeProgress%',
          contentTitle: title,
          summaryText: '$safeProgress%',
        ),
      );

      await _notifications.show(
        id: id,
        title: title,
        body: '$statusText • $safeProgress%',
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      _logger.w('Error showing download progress notification: $e');
    }
  }

  /// Show progress for playlist download with rich details
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
      final safeProgress = overallProgress.clamp(0, 100);

      final androidDetails = AndroidNotificationDetails(
        'download_channel',
        'Active Downloads',
        channelDescription:
            'Live progress notifications for active music downloads',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: 100,
        progress: safeProgress,
        ongoing: true,
        autoCancel: false,
        color: _primaryPurple,
        subText: 'Track $currentTrack of $totalTracks',
        category: AndroidNotificationCategory.progress,
        styleInformation: BigTextStyleInformation(
          '$currentSongTitle • $safeProgress%',
          contentTitle: playlistTitle,
          summaryText: '$safeProgress%',
        ),
      );

      await _notifications.show(
        id: id,
        title: playlistTitle,
        body: '[$currentTrack/$totalTracks] $currentSongTitle • $safeProgress%',
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
      final androidDetails = AndroidNotificationDetails(
        'download_complete_channel',
        'Download Completions',
        channelDescription: 'Notifications for completed downloads',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        color: _successGreen,
        subText: 'Download Finished',
        category: AndroidNotificationCategory.status,
        styleInformation: BigTextStyleInformation(
          subTitle ?? '$title has been added to your local library.',
          contentTitle: 'Download Complete',
          summaryText: 'Saved to Downloads',
        ),
      );

      await _notifications.show(
        id: id,
        title: 'Download Complete',
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
      final androidDetails = AndroidNotificationDetails(
        'download_error_channel',
        'Download Errors',
        channelDescription: 'Notifications for failed downloads',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        color: _errorRed,
        subText: 'Download Error',
        category: AndroidNotificationCategory.error,
        styleInformation: BigTextStyleInformation(
          errorReason ?? 'Unable to complete download for $title. Please check connection and try again.',
          contentTitle: 'Download Failed',
          summaryText: 'Tap to retry',
        ),
      );

      await _notifications.show(
        id: id,
        title: 'Download Failed',
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
