import 'package:equatable/equatable.dart';
import 'package:pixel_player/core/utils/jiosaavn_decoder.dart';

/// Represents a JioSaavn search result (song, album, artist or playlist).
class JioSaavnItem extends Equatable {
  /// Raw item type: "song" | "album" | "artist" | "playlist"
  final String type;
  final String id;
  final String token;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String? language;
  final String? year;

  // Song-specific
  final String? encryptedMediaUrl;
  final String? directMediaUrl;
  final String? duration;
  final String quality;

  // Album-specific
  final String? songCount;

  const JioSaavnItem({
    required this.type,
    required this.id,
    required this.token,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.language,
    this.year,
    this.encryptedMediaUrl,
    this.directMediaUrl,
    this.duration,
    this.quality = '320 kbps',
    this.songCount,
  });

  bool get isSong => type == 'song';
  bool get isAlbum => type == 'album';
  bool get isArtist => type == 'artist';
  bool get isPlaylist => type == 'playlist';

  factory JioSaavnItem.fromSongJson(Map<String, dynamic> json) {
    final moreInfo = json['more_info'] as Map<String, dynamic>? ?? {};
    final encUrl = moreInfo['encrypted_media_url']?.toString();
    final direct = JioSaavnDecoder.decryptMediaUrl(encUrl);
    final is320 = moreInfo['320kbps']?.toString() != 'false';
    final q = is320 ? '320 kbps' : '160 kbps';
    return JioSaavnItem(
      type: 'song',
      id: json['id']?.toString() ?? '',
      token: json['token']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      imageUrl: (json['image']?.toString() ?? '').replaceAll('150x150', '500x500'),
      language: json['language']?.toString(),
      year: json['year']?.toString(),
      encryptedMediaUrl: encUrl,
      directMediaUrl: direct,
      duration: moreInfo['duration']?.toString(),
      quality: q,
    );
  }

  factory JioSaavnItem.fromAlbumJson(Map<String, dynamic> json) {
    final moreInfo = json['more_info'] as Map<String, dynamic>? ?? {};
    return JioSaavnItem(
      type: 'album',
      id: json['id']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      imageUrl: (json['image']?.toString() ?? '').replaceAll('150x150', '500x500'),
      language: json['language']?.toString(),
      year: json['year']?.toString(),
      quality: '320 kbps',
      songCount: moreInfo['song_count']?.toString(),
    );
  }

  factory JioSaavnItem.fromArtistJson(Map<String, dynamic> json) {
    return JioSaavnItem(
      type: 'artist',
      id: json['id']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      title: json['name']?.toString() ?? '',
      subtitle: 'Artist',
      imageUrl: (json['image']?.toString() ?? '').replaceAll('150x150', '500x500'),
    );
  }

  factory JioSaavnItem.fromPlaylistJson(Map<String, dynamic> json) {
    final moreInfo = json['more_info'] as Map<String, dynamic>? ?? {};
    return JioSaavnItem(
      type: 'playlist',
      id: json['id']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      imageUrl: (json['image']?.toString() ?? '').replaceAll('150x150', '500x500'),
      quality: '320 kbps',
      songCount: moreInfo['song_count']?.toString(),
    );
  }

  @override
  List<Object?> get props =>
      [type, id, token, title, subtitle, imageUrl, language, year, encryptedMediaUrl, directMediaUrl, duration, quality, songCount];
}

