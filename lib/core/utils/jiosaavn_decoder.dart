import 'dart:convert';
import 'package:dart_des/dart_des.dart';
import 'package:dio/dio.dart';

class JioSaavnDecoder {
  // Key documented for JioSaavn DES-ECB media decryption
  static const String _desKey = '38346591';
  static const String apiBase = 'https://jiosaavn-api-eight-beryl.vercel.app';

  /// Decrypts the `encrypted_media_url` into a playable/downloadable HTTPS MP4/AAC stream URL.
  static String? decryptMediaUrl(String? encryptedUrl, {bool highQuality = true}) {
    if (encryptedUrl == null || encryptedUrl.trim().isEmpty) return null;
    try {
      final key = utf8.encode(_desKey);
      final des = DES(
        key: key,
        mode: DESMode.ECB,
        paddingType: DESPaddingType.PKCS7,
      );
      final decryptedBytes = des.decrypt(base64.decode(encryptedUrl.trim()));
      var decUrl = utf8.decode(decryptedBytes).trim();
      if (!decUrl.startsWith('http')) return null;

      if (highQuality) {
        decUrl = decUrl.replaceAll(RegExp(r'_96\.mp4|_160\.mp4|_320\.mp4'), '_320.mp4');
      }
      return decUrl;
    } catch (_) {
      return null;
    }
  }

  /// Fetches track media URLs for an album using the JioSaavn API.
  static Future<List<Map<String, String>>> fetchAlbumTracks(String albumToken) async {
    final dio = Dio();
    try {
      final resp = await dio.get(
        '$apiBase/api/album',
        queryParameters: {'token': albumToken},
      );
      final data = resp.data;
      if (data is Map && data['songs'] is List) {
        final list = <Map<String, String>>[];
        for (final song in data['songs'] as List) {
          final s = Map<String, dynamic>.from(song as Map);
          final title = s['title']?.toString() ?? 'Track';
          final encUrl = s['encrypted_media_url']?.toString();
          final directUrl = decryptMediaUrl(encUrl);
          if (directUrl != null) {
            list.add({'title': title, 'url': directUrl});
          }
        }
        return list;
      }
    } catch (_) {} finally {
      dio.close();
    }
    return [];
  }

  /// Fetches track media URLs for a playlist using the JioSaavn API.
  static Future<List<Map<String, String>>> fetchPlaylistTracks(String playlistToken) async {
    final dio = Dio();
    try {
      final resp = await dio.get(
        '$apiBase/api/playlist',
        queryParameters: {'token': playlistToken},
      );
      final data = resp.data;
      if (data is Map && data['list'] is List) {
        final list = <Map<String, String>>[];
        for (final song in data['list'] as List) {
          final s = Map<String, dynamic>.from(song as Map);
          final title = s['title']?.toString() ?? 'Track';
          final encUrl = s['encrypted_media_url']?.toString();
          final directUrl = decryptMediaUrl(encUrl);
          if (directUrl != null) {
            list.add({'title': title, 'url': directUrl});
          }
        }
        return list;
      }
    } catch (_) {} finally {
      dio.close();
    }
    return [];
  }
}

