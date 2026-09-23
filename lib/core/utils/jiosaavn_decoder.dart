import 'dart:convert';
import 'package:dart_des/dart_des.dart';
import 'package:dio/dio.dart';
import 'package:pixel_player/data/models/jiosaavn_item.dart';

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
        final albumTitle = data['title']?.toString();
        final albumArt = (data['image']?.toString() ?? '').replaceAll('150x150', '500x500');
        for (final song in data['songs'] as List) {
          final s = Map<String, dynamic>.from(song as Map);
          final title = s['title']?.toString() ?? 'Track';
          final moreInfo = s['more_info'] as Map<String, dynamic>?;
          final encUrl = s['encrypted_media_url']?.toString() ??
              moreInfo?['encrypted_media_url']?.toString();
          final directUrl = decryptMediaUrl(encUrl);
          final artist = s['subtitle']?.toString();
          if (directUrl != null) {
            list.add({
              'title': title,
              'url': directUrl,
              if (artist != null) 'artist': artist,
              if (albumTitle != null) 'album': albumTitle,
              if (albumArt.isNotEmpty) 'albumArt': albumArt,
            });
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
      final songList = data is Map ? (data['list'] ?? data['songs']) : null;
      if (data is Map && songList is List) {
        final list = <Map<String, String>>[];
        final playlistTitle = data['title']?.toString();
        final playlistArt = (data['image']?.toString() ?? '').replaceAll('150x150', '500x500');
        for (final song in songList) {
          final s = Map<String, dynamic>.from(song as Map);
          final title = s['title']?.toString() ?? 'Track';
          final moreInfo = s['more_info'] as Map<String, dynamic>?;
          final encUrl = s['encrypted_media_url']?.toString() ??
              moreInfo?['encrypted_media_url']?.toString();
          final directUrl = decryptMediaUrl(encUrl);
          final artist = s['subtitle']?.toString();
          if (directUrl != null) {
            list.add({
              'title': title,
              'url': directUrl,
              if (artist != null) 'artist': artist,
              if (playlistTitle != null) 'album': playlistTitle,
              if (playlistArt.isNotEmpty) 'albumArt': playlistArt,
            });
          }
        }
        return list;
      }
    } catch (_) {} finally {
      dio.close();
    }
    return [];
  }

  /// Fetches complete JioSaavnItem objects for all tracks in an album.
  static Future<List<JioSaavnItem>> fetchAlbumSongs(String albumToken) async {
    final dio = Dio();
    try {
      final resp = await dio.get(
        '$apiBase/api/album',
        queryParameters: {'token': albumToken},
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      final data = resp.data;
      if (data is Map && data['songs'] is List) {
        final list = <JioSaavnItem>[];
        final albumArt = (data['image']?.toString() ?? '').replaceAll('150x150', '500x500');
        final albumTitle = data['title']?.toString() ?? 'Album';
        for (final song in data['songs'] as List) {
          final s = Map<String, dynamic>.from(song as Map);
          final moreInfo = s['more_info'] as Map<String, dynamic>?;
          final encUrl = s['encrypted_media_url']?.toString() ??
              moreInfo?['encrypted_media_url']?.toString();
          final directUrl = decryptMediaUrl(encUrl);
          final songId = s['id']?.toString() ?? s['token']?.toString() ?? '';
          final durationSecs = s['duration']?.toString() ?? moreInfo?['duration']?.toString();
          final songArt = (s['image']?.toString() ?? '').replaceAll('150x150', '500x500');
          list.add(JioSaavnItem(
            type: 'song',
            id: songId,
            token: s['token']?.toString() ?? songId,
            title: s['title']?.toString() ?? 'Track',
            subtitle: s['subtitle']?.toString() ?? albumTitle,
            imageUrl: songArt.isNotEmpty ? songArt : albumArt,
            encryptedMediaUrl: encUrl,
            directMediaUrl: directUrl,
            duration: durationSecs,
            quality: '320 kbps',
          ));
        }
        return list;
      }
    } catch (_) {} finally {
      dio.close();
    }
    return [];
  }

  /// Fetches complete JioSaavnItem objects for all tracks in a playlist.
  static Future<List<JioSaavnItem>> fetchPlaylistSongs(String playlistToken) async {
    final dio = Dio();
    try {
      final resp = await dio.get(
        '$apiBase/api/playlist',
        queryParameters: {'token': playlistToken},
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      final data = resp.data;
      final songList = data is Map ? (data['list'] ?? data['songs']) : null;
      if (data is Map && songList is List) {
        final list = <JioSaavnItem>[];
        final playlistArt = (data['image']?.toString() ?? '').replaceAll('150x150', '500x500');
        final playlistTitle = data['title']?.toString() ?? 'Playlist';
        for (final song in songList) {
          final s = Map<String, dynamic>.from(song as Map);
          final moreInfo = s['more_info'] as Map<String, dynamic>?;
          final encUrl = s['encrypted_media_url']?.toString() ??
              moreInfo?['encrypted_media_url']?.toString();
          final directUrl = decryptMediaUrl(encUrl);
          final songId = s['id']?.toString() ?? s['token']?.toString() ?? '';
          final durationSecs = s['duration']?.toString() ?? moreInfo?['duration']?.toString();
          final songArt = (s['image']?.toString() ?? '').replaceAll('150x150', '500x500');
          list.add(JioSaavnItem(
            type: 'song',
            id: songId,
            token: s['token']?.toString() ?? songId,
            title: s['title']?.toString() ?? 'Track',
            subtitle: s['subtitle']?.toString() ?? playlistTitle,
            imageUrl: songArt.isNotEmpty ? songArt : playlistArt,
            encryptedMediaUrl: encUrl,
            directMediaUrl: directUrl,
            duration: durationSecs,
            quality: '320 kbps',
          ));
        }
        return list;
      }
    } catch (_) {} finally {
      dio.close();
    }
    return [];
  }
}

