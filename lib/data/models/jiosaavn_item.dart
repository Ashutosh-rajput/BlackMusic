import 'package:equatable/equatable.dart';
import 'package:pixel_player/core/utils/jiosaavn_decoder.dart';
import 'package:pixel_player/data/models/song_model.dart';

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

  final String? music;

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
    this.music,
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

  /// Converts this JioSaavnItem into a playable online Song model.
  Song toSong({String? albumName, String? overrideStreamUrl}) {
    final streamUrl = overrideStreamUrl ??
        directMediaUrl ??
        JioSaavnDecoder.decryptMediaUrl(encryptedMediaUrl) ??
        '';
    final durSecs = int.tryParse(duration ?? '0') ?? 0;
    final parsedId = int.tryParse(id);
    final idHash = parsedId ?? (id.isNotEmpty ? id : token).hashCode.abs();
    return Song(
      id: idHash != 0 ? idHash : DateTime.now().millisecondsSinceEpoch,
      title: title.isNotEmpty ? title : 'Track',
      artist: subtitle.isNotEmpty ? subtitle : 'JioSaavn Artist',
      album: albumName ?? (isAlbum ? title : (subtitle.isNotEmpty ? subtitle : 'JioSaavn')),
      filePath: streamUrl,
      duration: Duration(seconds: durSecs > 0 ? durSecs : 180),
      dateModified: DateTime.now(),
      genre: 'Streaming',
      albumArtist: subtitle,
      albumArt: imageUrl,
      source: 'jiosaavn',
      audioQuality: quality.isNotEmpty ? quality : '320 kbps',
    );
  }

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
      music: moreInfo['music']?.toString(),
      encryptedMediaUrl: encUrl,
      directMediaUrl: direct,
      duration: moreInfo['duration']?.toString(),
      quality: q,
    );
  }

  factory JioSaavnItem.fromAlbumJson(Map<String, dynamic> json) {
    final moreInfo = json['more_info'] as Map<String, dynamic>? ?? {};
    final id = json['id']?.toString() ?? '';
    final tok = json['token']?.toString();
    return JioSaavnItem(
      type: 'album',
      id: id,
      token: (tok != null && tok.isNotEmpty) ? tok : id,
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
    final id = json['id']?.toString() ?? '';
    final tok = json['token']?.toString();
    return JioSaavnItem(
      type: 'artist',
      id: id,
      token: (tok != null && tok.isNotEmpty) ? tok : id,
      title: json['name']?.toString() ?? '',
      subtitle: 'Artist',
      imageUrl: (json['image']?.toString() ?? '').replaceAll('150x150', '500x500'),
    );
  }

  factory JioSaavnItem.fromPlaylistJson(Map<String, dynamic> json) {
    final moreInfo = json['more_info'] as Map<String, dynamic>? ?? {};
    final id = json['id']?.toString() ?? '';
    final tok = json['token']?.toString();
    return JioSaavnItem(
      type: 'playlist',
      id: id,
      token: (tok != null && tok.isNotEmpty) ? tok : id,
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      imageUrl: (json['image']?.toString() ?? '').replaceAll('150x150', '500x500'),
      quality: '320 kbps',
      songCount: moreInfo['song_count']?.toString(),
    );
  }

  @override
  List<Object?> get props =>
      [type, id, token, title, subtitle, imageUrl, language, year, music, encryptedMediaUrl, directMediaUrl, duration, quality, songCount];
}

