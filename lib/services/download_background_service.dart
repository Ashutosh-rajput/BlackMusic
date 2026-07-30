import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

const String _downloadKeepAliveChannelId = 'download_keep_alive_channel';
const int _downloadKeepAliveNotificationId = 445566;

/// Configures a lightweight foreground-service "shield" that keeps the app
/// process alive while a download is in flight and no audio is playing.
///
/// Without this, Android is free to reclaim the process within seconds of
/// the app losing all UI and foreground services (e.g. right after a shared
/// download snaps the app back to the app it was shared from), truncating
/// in-progress downloads. Must be called once during app startup, before
/// [DownloadService] can start/stop the shield.
Future<void> initializeDownloadBackgroundService() async {
  const channel = AndroidNotificationChannel(
    _downloadKeepAliveChannelId,
    'Background Downloads',
    description: 'Keeps song downloads running after leaving the app',
    importance: Importance.low,
  );

  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FlutterBackgroundService().configure(
    iosConfiguration: IosConfiguration(autoStart: false),
    androidConfiguration: AndroidConfiguration(
      onStart: _onDownloadKeepAliveStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: _downloadKeepAliveChannelId,
      initialNotificationTitle: 'BlackMusic',
      initialNotificationContent: 'Downloading song…',
      foregroundServiceNotificationId: _downloadKeepAliveNotificationId,
      foregroundServiceTypes: const [AndroidForegroundType.dataSync],
    ),
  );
}

/// Runs in a separate background isolate. It does no work of its own — the
/// real download pipeline (DownloadService) keeps running in the main
/// isolate; this isolate exists purely so Android sees an active foreground
/// service and won't reclaim the process while it's alive.
@pragma('vm:entry-point')
void _onDownloadKeepAliveStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

/// Starts the keep-alive shield. Safe to call even if already running.
Future<void> startDownloadKeepAlive() async {
  try {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  } catch (e) {
    _logger.w('Failed to start download keep-alive service: $e');
  }
}

/// Stops the keep-alive shield once no downloads remain in flight.
Future<void> stopDownloadKeepAlive() async {
  try {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  } catch (e) {
    _logger.w('Failed to stop download keep-alive service: $e');
  }
}
