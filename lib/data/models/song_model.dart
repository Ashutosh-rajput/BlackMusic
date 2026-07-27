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
  });

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
      ];
}
