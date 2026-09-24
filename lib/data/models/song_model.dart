import 'package:equatable/equatable.dart';

class Song extends Equatable {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final Duration duration;
  final int? fileSize;
  final DateTime dateModified;
  final String? genre;
  final String? albumArtist;
  final String? albumArt;

  // Play tracking
  final int playCount;
  final DateTime? lastPlayedAt;
  /// 'local', 'youtube', 'jiosaavn'
  final String? source;
  /// e.g. '320 kbps', '128 kbps', 'HD Audio'
  final String? audioQuality;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    required this.duration,
    this.fileSize,
    required this.dateModified,
    this.genre,
    this.albumArtist,
    this.albumArt,
    this.playCount = 0,
    this.lastPlayedAt,
    this.source,
    this.audioQuality,
  });

  String get effectiveSource {
    if (source != null && source != 'local') {
      return source!;
    }
    if (album == 'YouTube Downloads') {
      return 'youtube';
    }
    final lowerPath = filePath.toLowerCase();
    if (album == 'JioSaavn' ||
        genre == 'Downloaded' ||
        lowerPath.contains('blackmusic') ||
        lowerPath.contains('saavn')) {
      return 'jiosaavn';
    }
    return source ?? 'local';
  }

  String? get effectiveAudioQuality {
    if (audioQuality != null && audioQuality!.isNotEmpty) {
      return audioQuality;
    }
    if (effectiveSource == 'jiosaavn') {
      return '320 kbps';
    }
    if (effectiveSource == 'youtube') {
      return 'HD Audio';
    }
    return null;
  }

  String get folderName {
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return 'Online Streams';
    }
    final parts = filePath.split(RegExp(r'[/\\]'));
    if (parts.length > 1) {
      return parts[parts.length - 2];
    }
    return 'Root';
  }

  String get folderPath {
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return 'Online';
    }
    final parts = filePath.split(RegExp(r'[/\\]'));
    if (parts.length > 1) {
      return parts.sublist(0, parts.length - 1).join('/');
    }
    return '/';
  }

  Song copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    String? filePath,
    Duration? duration,
    int? fileSize,
    DateTime? dateModified,
    String? genre,
    String? albumArtist,
    String? albumArt,
    int? playCount,
    DateTime? lastPlayedAt,
    String? source,
    String? audioQuality,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      dateModified: dateModified ?? this.dateModified,
      genre: genre ?? this.genre,
      albumArtist: albumArtist ?? this.albumArtist,
      albumArt: albumArt ?? this.albumArt,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      source: source ?? this.source,
      audioQuality: audioQuality ?? this.audioQuality,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'filePath': filePath,
      'durationMs': duration.inMilliseconds,
      'fileSize': fileSize,
      'dateModified': dateModified.toIso8601String(),
      'genre': genre,
      'albumArtist': albumArtist,
      'albumArt': albumArt,
      'playCount': playCount,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      'source': source,
      'audioQuality': audioQuality,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as int,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      filePath: json['filePath'] as String,
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      fileSize: json['fileSize'] as int?,
      dateModified: DateTime.parse(json['dateModified'] as String),
      genre: json['genre'] as String?,
      albumArtist: json['albumArtist'] as String?,
      albumArt: json['albumArt'] as String?,
      playCount: json['playCount'] as int? ?? 0,
      lastPlayedAt: json['lastPlayedAt'] != null
          ? DateTime.parse(json['lastPlayedAt'] as String)
          : null,
      source: json['source'] as String?,
      audioQuality: json['audioQuality'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        artist,
        album,
        filePath,
        duration,
        fileSize,
        dateModified,
        genre,
        albumArtist,
        albumArt,
        playCount,
        lastPlayedAt,
        source,
        audioQuality,
      ];
}
