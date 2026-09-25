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
      if (decUrl.startsWith('http://')) {
        decUrl = decUrl.replaceFirst('http://', 'https://');
      }

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
          Map<String, dynamic>? moreInfo;
          if (s['more_info'] is Map) {
            moreInfo = Map<String, dynamic>.from(s['more_info'] as Map);
          }
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
          Map<String, dynamic>? moreInfo;
          if (s['more_info'] is Map) {
            moreInfo = Map<String, dynamic>.from(s['more_info'] as Map);
          }
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

  /// Parses any JioSaavn JSON item into a JioSaavnItem
  static JioSaavnItem parseItem(Map<String, dynamic> item) {
    final type = item['type']?.toString().toLowerCase() ?? 'album';
    final id = item['id']?.toString() ?? '';
    final token = item['token']?.toString() ?? id;
    final title = item['title']?.toString() ?? '';
    var subtitle = item['subtitle']?.toString() ?? '';
    final image = (item['image']?.toString() ?? '').replaceAll('150x150', '500x500');
    Map<String, dynamic>? moreInfo;
    if (item['more_info'] is Map) {
      moreInfo = Map<String, dynamic>.from(item['more_info'] as Map);
    }
    if (subtitle.isEmpty && moreInfo != null) {
      final artistMap = moreInfo['artistMap'];
      if (artistMap is Map && artistMap['primary_artists'] is List) {
        final names = (artistMap['primary_artists'] as List)
            .whereType<Map>()
            .map((a) => a['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toList();
        if (names.isNotEmpty) {
          subtitle = names.join(', ');
        }
      }
      if (subtitle.isEmpty && moreInfo['music'] != null) {
        subtitle = moreInfo['music'].toString();
      } else if (subtitle.isEmpty && moreInfo['album'] != null) {
        subtitle = moreInfo['album'].toString();
      }
    }
    final encUrl = item['encrypted_media_url']?.toString() ??
        moreInfo?['encrypted_media_url']?.toString();
    final direct = decryptMediaUrl(encUrl);
    final duration = item['duration']?.toString() ?? moreInfo?['duration']?.toString();
    final songCount = item['song_count']?.toString() ?? moreInfo?['song_count']?.toString();

    return JioSaavnItem(
      type: type,
      id: id,
      token: token,
      title: title,
      subtitle: subtitle,
      imageUrl: image,
      language: item['language']?.toString(),
      year: item['year']?.toString(),
      encryptedMediaUrl: encUrl,
      directMediaUrl: direct,
      duration: duration,
      songCount: songCount,
      quality: '320 kbps',
    );
  }

  /// Fetches related albums for an album ID
  static Future<List<JioSaavnItem>> fetchRelatedAlbums(String albumId) async {
    final dio = Dio();
    try {
      final resp = await dio.get(
        '$apiBase/api/related',
        queryParameters: {'id': albumId},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      final data = resp.data;
      final results = data is Map ? data['results'] : (data is List ? data : null);
      if (results is List) {
        return results
            .whereType<Map>()
            .map((e) => parseItem(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {} finally {
      dio.close();
    }
    return [];
  }

  /// Fetches new releases for language
  static Future<List<JioSaavnItem>> fetchNewReleases({String lang = 'hindi'}) async {
    final dio = Dio();
    try {
      final resp = await dio.get(
        '$apiBase/api/new',
        queryParameters: {'lang': lang},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      final data = resp.data;
      final results = data is List ? data : (data is Map ? (data['results'] ?? data['data']) : null);
      if (results is List) {
        return results
            .whereType<Map>()
            .map((e) => parseItem(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {} finally {
      dio.close();
    }
    return [];
  }

  /// Fetches home feed for language (e.g. Trending Now, Top Charts, Editorial Picks)
  static Future<Map<String, List<JioSaavnItem>>> fetchHomeFeed({String lang = 'hindi'}) async {
    final dio = Dio();
    final feed = <String, List<JioSaavnItem>>{};
    try {
      final resp = await dio.get(
        '$apiBase/api/home',
        queryParameters: {'lang': lang},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      final data = resp.data;
      if (data is Map) {
        // 1. Process 'modules' list which contains categorized sections
        final modules = data['modules'];
        if (modules is List) {
          for (final m in modules) {
            if (m is Map) {
              final modTitle = m['title']?.toString();
              if (modTitle != null && modTitle.trim().toLowerCase() == 'new releases') {
                // Skip duplicate "New Releases" since it is already fetched via /api/new
                continue;
              }
              final itemsList = m['items'];
              if (modTitle != null && modTitle.isNotEmpty && itemsList is List && itemsList.isNotEmpty) {
                final list = itemsList
                    .whereType<Map>()
                    .map((e) => parseItem(Map<String, dynamic>.from(e)))
                    .where((item) => item.title.isNotEmpty)
                    .toList();
                if (list.isNotEmpty) {
                  feed[modTitle] = list;
                }
              }
            }
          }
        }

        // 2. Also process any direct top-level list keys
        for (final entry in data.entries) {
          final key = entry.key.toString();
          if (key == 'modules' || key == 'language' || key.toLowerCase() == 'new_releases') continue;
          final val = entry.value;
          if (val is List && val.isNotEmpty) {
            final list = val
                .whereType<Map>()
                .map((e) => parseItem(Map<String, dynamic>.from(e)))
                .where((item) => item.title.isNotEmpty)
                .toList();
            if (list.isNotEmpty) {
              final formattedTitle = key
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
                  .join(' ');
              feed[formattedTitle] = list;
            }
          }
        }
      }
    } catch (_) {} finally {
      dio.close();
    }
    return feed;
  }

  /// Search songs by query
  static Future<List<JioSaavnItem>> searchSongs(String query) async {
    if (query.trim().isEmpty) return [];
    final dio = Dio();
    try {
      final resp = await dio.get(
        '$apiBase/api/songs',
        queryParameters: {'q': query.trim()},
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final data = resp.data;
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .whereType<Map>()
            .map((e) => parseItem(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {} finally {
      dio.close();
    }
    return [];
  }

  /// Search playlists by query
  static Future<List<JioSaavnItem>> searchPlaylists(String query) async {
    if (query.trim().isEmpty) return [];
    final dio = Dio();
    try {
      final resp = await dio.get(
        '$apiBase/api/playlists',
        queryParameters: {'q': query.trim()},
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final data = resp.data;
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .whereType<Map>()
            .map((e) => parseItem(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {} finally {
      dio.close();
    }
    return [];
  }

  /// Search albums by query
  static Future<List<JioSaavnItem>> searchAlbums(String query) async {
    final dio = Dio();
    try {
      final resp = await dio.get(
        '$apiBase/api/albums',
        queryParameters: {'q': query},
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final data = resp.data;
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .whereType<Map>()
            .map((e) => parseItem(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {} finally {
      dio.close();
    }
    return [];
  }

  /// Fetches complete details and direct stream URL for a single song
  static Future<JioSaavnItem?> fetchSongDetails(String token) async {
    final dio = Dio();
    try {
      final resp = await dio.get(
        '$apiBase/api/song',
        queryParameters: {'token': token},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      final data = resp.data;
      if (data is Map) {
        return parseItem(Map<String, dynamic>.from(data));
      }
    } catch (_) {} finally {
      dio.close();
    }
    return null;
  }

  /// Fetches song suggestions/recommendations based on a song ID
  /// using JioSaavn's reco.getreco recommendation engine.
  static Future<List<JioSaavnItem>> fetchSongSuggestions(String songId, {int limit = 10}) async {
    if (songId.trim().isEmpty) return [];
    final dio = Dio();
    try {
      final directResp = await dio.get(
        'https://www.jiosaavn.com/api.php',
        queryParameters: {
          '__call': 'reco.getreco',
          'api_version': '4',
          '_format': 'json',
          '_marker': '0',
          'ctx': 'android',
          'pid': songId.trim(),
          'n': limit,
        },
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final rawData = directResp.data;
      final dynamic parsed = rawData is String ? jsonDecode(rawData) : rawData;
      List rawList = [];
      if (parsed is List) {
        rawList = parsed;
      } else if (parsed is Map) {
        final val = parsed[songId.trim()];
        if (val is List) {
          rawList = val;
        } else if (parsed.isNotEmpty && parsed.values.first is List) {
          rawList = parsed.values.first as List;
        }
      }

      if (rawList.isNotEmpty) {
        return rawList
            .whereType<Map>()
            .map((e) => parseItem(Map<String, dynamic>.from(e)))
            .where((item) => item.title.isNotEmpty)
            .take(limit)
            .toList();
      }
    } catch (_) {
    } finally {
      dio.close();
    }
    return [];
  }
}

