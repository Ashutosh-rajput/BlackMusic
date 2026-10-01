import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A newer release published on GitHub.
class AppUpdate {
  final String version;
  final String notes;

  /// The release page the "Update" button opens.
  final String url;

  const AppUpdate({required this.version, required this.notes, required this.url});
}

/// Checks the GitHub repo for a release newer than the installed app.
class UpdateService {
  static const String repoUrl = 'https://github.com/Ashutosh-rajput/Vinyl';
  static const String _latestReleaseApi =
      'https://api.github.com/repos/Ashutosh-rajput/Vinyl/releases/latest';
  static const String _skippedKey = 'update_skipped_version';

  /// Returns the newer release, or null when up to date, when the user chose
  /// to skip that version, or when the check fails (no internet, rate limit).
  /// Never throws: an update check must not get in the way of the app.
  static Future<AppUpdate?> checkForUpdate({bool ignoreSkipped = false}) async {
    final dio = Dio();
    try {
      final info = await PackageInfo.fromPlatform();
      final resp = await dio.get(
        _latestReleaseApi,
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
          headers: {'Accept': 'application/vnd.github+json'},
        ),
      );
      final data = resp.data;
      if (data is! Map || data['draft'] == true || data['prerelease'] == true) return null;

      final tag = data['tag_name']?.toString() ?? '';
      if (!isNewerVersion(tag, info.version)) return null;

      if (!ignoreSkipped) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString(_skippedKey) == tag) return null;
      }

      return AppUpdate(
        version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
        notes: (data['body']?.toString() ?? '').trim(),
        url: data['html_url']?.toString() ?? '$repoUrl/releases/latest',
      );
    } catch (e) {
      debugPrint('Update check skipped: $e');
      return null;
    } finally {
      dio.close();
    }
  }

  /// Remembers "don't remind me about this version".
  static Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedKey, version.startsWith(RegExp(r'[vV]')) ? version : 'v$version');
  }

  /// True when [latest] (e.g. "v1.7.0") is a higher version than [current]
  /// (e.g. "1.0.0"). Compares numbers, so 1.10.0 is newer than 1.9.0.
  /// Anything that does not parse is treated as "not newer".
  @visibleForTesting
  static bool isNewerVersion(String latest, String current) {
    List<int>? parse(String v) {
      final core = v.trim().replaceFirst(RegExp(r'^[vV]'), '').split(RegExp(r'[+\-]')).first;
      final parts = core.split('.').map(int.tryParse).toList();
      if (parts.isEmpty || parts.any((p) => p == null)) return null;
      return parts.cast<int>();
    }

    final a = parse(latest);
    final b = parse(current);
    if (a == null || b == null) return false;
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
