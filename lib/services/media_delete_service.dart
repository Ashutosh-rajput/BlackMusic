import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum MediaDeleteResult {
  /// The file was removed from the device.
  deleted,

  /// The file was already gone; treat as deleted.
  notFound,

  /// The user declined the system delete prompt.
  cancelled,

  /// Android would not allow the delete.
  failed,
}

/// Deletes audio files from device storage.
///
/// On Android 10+ a file created by another app (e.g. music copied onto the
/// phone) can't be deleted with a plain `File.delete()`. The native side
/// asks the user through the system "Allow Vinyl to delete this audio?"
/// prompt in that case. See `MainActivity.kt`.
class MediaDeleteService {
  static const _channel = MethodChannel('com.muskmelon.vinyl/media_delete');

  static Future<MediaDeleteResult> deleteAudioFile(String path) async {
    if (!Platform.isAndroid) return _deleteDirectly(path);

    var result = await _deleteOnAndroid(path);
    if (result == MediaDeleteResult.failed) {
      // Android 9 and below need the legacy storage permission. On newer
      // versions this is a no-op (the permission isn't declared there).
      final status = await Permission.storage.request();
      if (status.isGranted) result = await _deleteOnAndroid(path);
    }
    return result;
  }

  static Future<MediaDeleteResult> _deleteOnAndroid(String path) async {
    try {
      final raw = await _channel.invokeMethod<String>('deleteAudioFile', {'path': path});
      switch (raw) {
        case 'deleted':
          return MediaDeleteResult.deleted;
        case 'not_found':
          return MediaDeleteResult.notFound;
        case 'cancelled':
          return MediaDeleteResult.cancelled;
        default:
          return MediaDeleteResult.failed;
      }
    } catch (e) {
      debugPrint('MediaDeleteService: native delete failed: $e');
      // Channel unavailable (e.g. tests): fall back to a plain delete.
      return _deleteDirectly(path);
    }
  }

  static Future<MediaDeleteResult> _deleteDirectly(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return MediaDeleteResult.notFound;
      await file.delete();
      return MediaDeleteResult.deleted;
    } catch (e) {
      debugPrint('MediaDeleteService: delete failed for $path: $e');
      return MediaDeleteResult.failed;
    }
  }
}
