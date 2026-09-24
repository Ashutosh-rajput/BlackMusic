// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SongsTable extends Songs with TableInfo<$SongsTable, Song> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
      'album', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _durationMeta =
      const VerificationMeta('duration');
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
      'duration', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fileSizeMeta =
      const VerificationMeta('fileSize');
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
      'file_size', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _dateModifiedMeta =
      const VerificationMeta('dateModified');
  @override
  late final GeneratedColumn<DateTime> dateModified = GeneratedColumn<DateTime>(
      'date_modified', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
      'genre', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _albumArtistMeta =
      const VerificationMeta('albumArtist');
  @override
  late final GeneratedColumn<String> albumArtist = GeneratedColumn<String>(
      'album_artist', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _albumArtMeta =
      const VerificationMeta('albumArt');
  @override
  late final GeneratedColumn<String> albumArt = GeneratedColumn<String>(
      'album_art', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _playCountMeta =
      const VerificationMeta('playCount');
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
      'play_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastPlayedAtMeta =
      const VerificationMeta('lastPlayedAt');
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
      'last_played_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _audioQualityMeta =
      const VerificationMeta('audioQuality');
  @override
  late final GeneratedColumn<String> audioQuality = GeneratedColumn<String>(
      'audio_quality', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
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
        audioQuality
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(Insertable<Song> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
          _albumMeta, album.isAcceptableOrUnknown(data['album']!, _albumMeta));
    } else if (isInserting) {
      context.missing(_albumMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta,
          duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(_fileSizeMeta,
          fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta));
    }
    if (data.containsKey('date_modified')) {
      context.handle(
          _dateModifiedMeta,
          dateModified.isAcceptableOrUnknown(
              data['date_modified']!, _dateModifiedMeta));
    } else if (isInserting) {
      context.missing(_dateModifiedMeta);
    }
    if (data.containsKey('genre')) {
      context.handle(
          _genreMeta, genre.isAcceptableOrUnknown(data['genre']!, _genreMeta));
    }
    if (data.containsKey('album_artist')) {
      context.handle(
          _albumArtistMeta,
          albumArtist.isAcceptableOrUnknown(
              data['album_artist']!, _albumArtistMeta));
    }
    if (data.containsKey('album_art')) {
      context.handle(_albumArtMeta,
          albumArt.isAcceptableOrUnknown(data['album_art']!, _albumArtMeta));
    }
    if (data.containsKey('play_count')) {
      context.handle(_playCountMeta,
          playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta));
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
          _lastPlayedAtMeta,
          lastPlayedAt.isAcceptableOrUnknown(
              data['last_played_at']!, _lastPlayedAtMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('audio_quality')) {
      context.handle(
          _audioQualityMeta,
          audioQuality.isAcceptableOrUnknown(
              data['audio_quality']!, _audioQualityMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Song map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Song(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      album: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      duration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration'])!,
      fileSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size']),
      dateModified: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}date_modified'])!,
      genre: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genre']),
      albumArtist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album_artist']),
      albumArt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album_art']),
      playCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}play_count'])!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_played_at']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source']),
      audioQuality: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_quality']),
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class Song extends DataClass implements Insertable<Song> {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final int duration;
  final int? fileSize;
  final DateTime dateModified;
  final String? genre;
  final String? albumArtist;
  final String? albumArt;
  final int playCount;
  final DateTime? lastPlayedAt;
  final String? source;
  final String? audioQuality;
  const Song(
      {required this.id,
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
      required this.playCount,
      this.lastPlayedAt,
      this.source,
      this.audioQuality});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['album'] = Variable<String>(album);
    map['file_path'] = Variable<String>(filePath);
    map['duration'] = Variable<int>(duration);
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    map['date_modified'] = Variable<DateTime>(dateModified);
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || albumArtist != null) {
      map['album_artist'] = Variable<String>(albumArtist);
    }
    if (!nullToAbsent || albumArt != null) {
      map['album_art'] = Variable<String>(albumArt);
    }
    map['play_count'] = Variable<int>(playCount);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || audioQuality != null) {
      map['audio_quality'] = Variable<String>(audioQuality);
    }
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      filePath: Value(filePath),
      duration: Value(duration),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      dateModified: Value(dateModified),
      genre:
          genre == null && nullToAbsent ? const Value.absent() : Value(genre),
      albumArtist: albumArtist == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArtist),
      albumArt: albumArt == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArt),
      playCount: Value(playCount),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      source:
          source == null && nullToAbsent ? const Value.absent() : Value(source),
      audioQuality: audioQuality == null && nullToAbsent
          ? const Value.absent()
          : Value(audioQuality),
    );
  }

  factory Song.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Song(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      filePath: serializer.fromJson<String>(json['filePath']),
      duration: serializer.fromJson<int>(json['duration']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      dateModified: serializer.fromJson<DateTime>(json['dateModified']),
      genre: serializer.fromJson<String?>(json['genre']),
      albumArtist: serializer.fromJson<String?>(json['albumArtist']),
      albumArt: serializer.fromJson<String?>(json['albumArt']),
      playCount: serializer.fromJson<int>(json['playCount']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
      source: serializer.fromJson<String?>(json['source']),
      audioQuality: serializer.fromJson<String?>(json['audioQuality']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'filePath': serializer.toJson<String>(filePath),
      'duration': serializer.toJson<int>(duration),
      'fileSize': serializer.toJson<int?>(fileSize),
      'dateModified': serializer.toJson<DateTime>(dateModified),
      'genre': serializer.toJson<String?>(genre),
      'albumArtist': serializer.toJson<String?>(albumArtist),
      'albumArt': serializer.toJson<String?>(albumArt),
      'playCount': serializer.toJson<int>(playCount),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
      'source': serializer.toJson<String?>(source),
      'audioQuality': serializer.toJson<String?>(audioQuality),
    };
  }

  Song copyWith(
          {int? id,
          String? title,
          String? artist,
          String? album,
          String? filePath,
          int? duration,
          Value<int?> fileSize = const Value.absent(),
          DateTime? dateModified,
          Value<String?> genre = const Value.absent(),
          Value<String?> albumArtist = const Value.absent(),
          Value<String?> albumArt = const Value.absent(),
          int? playCount,
          Value<DateTime?> lastPlayedAt = const Value.absent(),
          Value<String?> source = const Value.absent(),
          Value<String?> audioQuality = const Value.absent()}) =>
      Song(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        filePath: filePath ?? this.filePath,
        duration: duration ?? this.duration,
        fileSize: fileSize.present ? fileSize.value : this.fileSize,
        dateModified: dateModified ?? this.dateModified,
        genre: genre.present ? genre.value : this.genre,
        albumArtist: albumArtist.present ? albumArtist.value : this.albumArtist,
        albumArt: albumArt.present ? albumArt.value : this.albumArt,
        playCount: playCount ?? this.playCount,
        lastPlayedAt:
            lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
        source: source.present ? source.value : this.source,
        audioQuality:
            audioQuality.present ? audioQuality.value : this.audioQuality,
      );
  Song copyWithCompanion(SongsCompanion data) {
    return Song(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      duration: data.duration.present ? data.duration.value : this.duration,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      dateModified: data.dateModified.present
          ? data.dateModified.value
          : this.dateModified,
      genre: data.genre.present ? data.genre.value : this.genre,
      albumArtist:
          data.albumArtist.present ? data.albumArtist.value : this.albumArtist,
      albumArt: data.albumArt.present ? data.albumArt.value : this.albumArt,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      source: data.source.present ? data.source.value : this.source,
      audioQuality: data.audioQuality.present
          ? data.audioQuality.value
          : this.audioQuality,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Song(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('filePath: $filePath, ')
          ..write('duration: $duration, ')
          ..write('fileSize: $fileSize, ')
          ..write('dateModified: $dateModified, ')
          ..write('genre: $genre, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('albumArt: $albumArt, ')
          ..write('playCount: $playCount, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('source: $source, ')
          ..write('audioQuality: $audioQuality')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
      audioQuality);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Song &&
          other.id == this.id &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.filePath == this.filePath &&
          other.duration == this.duration &&
          other.fileSize == this.fileSize &&
          other.dateModified == this.dateModified &&
          other.genre == this.genre &&
          other.albumArtist == this.albumArtist &&
          other.albumArt == this.albumArt &&
          other.playCount == this.playCount &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.source == this.source &&
          other.audioQuality == this.audioQuality);
}

class SongsCompanion extends UpdateCompanion<Song> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> album;
  final Value<String> filePath;
  final Value<int> duration;
  final Value<int?> fileSize;
  final Value<DateTime> dateModified;
  final Value<String?> genre;
  final Value<String?> albumArtist;
  final Value<String?> albumArt;
  final Value<int> playCount;
  final Value<DateTime?> lastPlayedAt;
  final Value<String?> source;
  final Value<String?> audioQuality;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.filePath = const Value.absent(),
    this.duration = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.dateModified = const Value.absent(),
    this.genre = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.albumArt = const Value.absent(),
    this.playCount = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.audioQuality = const Value.absent(),
  });
  SongsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String artist,
    required String album,
    required String filePath,
    required int duration,
    this.fileSize = const Value.absent(),
    required DateTime dateModified,
    this.genre = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.albumArt = const Value.absent(),
    this.playCount = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.audioQuality = const Value.absent(),
  })  : title = Value(title),
        artist = Value(artist),
        album = Value(album),
        filePath = Value(filePath),
        duration = Value(duration),
        dateModified = Value(dateModified);
  static Insertable<Song> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? filePath,
    Expression<int>? duration,
    Expression<int>? fileSize,
    Expression<DateTime>? dateModified,
    Expression<String>? genre,
    Expression<String>? albumArtist,
    Expression<String>? albumArt,
    Expression<int>? playCount,
    Expression<DateTime>? lastPlayedAt,
    Expression<String>? source,
    Expression<String>? audioQuality,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (filePath != null) 'file_path': filePath,
      if (duration != null) 'duration': duration,
      if (fileSize != null) 'file_size': fileSize,
      if (dateModified != null) 'date_modified': dateModified,
      if (genre != null) 'genre': genre,
      if (albumArtist != null) 'album_artist': albumArtist,
      if (albumArt != null) 'album_art': albumArt,
      if (playCount != null) 'play_count': playCount,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (source != null) 'source': source,
      if (audioQuality != null) 'audio_quality': audioQuality,
    });
  }

  SongsCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<String>? artist,
      Value<String>? album,
      Value<String>? filePath,
      Value<int>? duration,
      Value<int?>? fileSize,
      Value<DateTime>? dateModified,
      Value<String?>? genre,
      Value<String?>? albumArtist,
      Value<String?>? albumArt,
      Value<int>? playCount,
      Value<DateTime?>? lastPlayedAt,
      Value<String?>? source,
      Value<String?>? audioQuality}) {
    return SongsCompanion(
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

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (dateModified.present) {
      map['date_modified'] = Variable<DateTime>(dateModified.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (albumArtist.present) {
      map['album_artist'] = Variable<String>(albumArtist.value);
    }
    if (albumArt.present) {
      map['album_art'] = Variable<String>(albumArt.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (audioQuality.present) {
      map['audio_quality'] = Variable<String>(audioQuality.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('filePath: $filePath, ')
          ..write('duration: $duration, ')
          ..write('fileSize: $fileSize, ')
          ..write('dateModified: $dateModified, ')
          ..write('genre: $genre, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('albumArt: $albumArt, ')
          ..write('playCount: $playCount, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('source: $source, ')
          ..write('audioQuality: $audioQuality')
          ..write(')'))
        .toString();
  }
}

class $PlayHistoryTable extends PlayHistory
    with TableInfo<$PlayHistoryTable, PlayHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<int> songId = GeneratedColumn<int>(
      'song_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _playedAtMeta =
      const VerificationMeta('playedAt');
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
      'played_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, songId, playedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_history';
  @override
  VerificationContext validateIntegrity(Insertable<PlayHistoryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta,
          songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(_playedAtMeta,
          playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta));
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayHistoryData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      songId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}song_id'])!,
      playedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}played_at'])!,
    );
  }

  @override
  $PlayHistoryTable createAlias(String alias) {
    return $PlayHistoryTable(attachedDatabase, alias);
  }
}

class PlayHistoryData extends DataClass implements Insertable<PlayHistoryData> {
  final int id;
  final int songId;
  final DateTime playedAt;
  const PlayHistoryData(
      {required this.id, required this.songId, required this.playedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['song_id'] = Variable<int>(songId);
    map['played_at'] = Variable<DateTime>(playedAt);
    return map;
  }

  PlayHistoryCompanion toCompanion(bool nullToAbsent) {
    return PlayHistoryCompanion(
      id: Value(id),
      songId: Value(songId),
      playedAt: Value(playedAt),
    );
  }

  factory PlayHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayHistoryData(
      id: serializer.fromJson<int>(json['id']),
      songId: serializer.fromJson<int>(json['songId']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'songId': serializer.toJson<int>(songId),
      'playedAt': serializer.toJson<DateTime>(playedAt),
    };
  }

  PlayHistoryData copyWith({int? id, int? songId, DateTime? playedAt}) =>
      PlayHistoryData(
        id: id ?? this.id,
        songId: songId ?? this.songId,
        playedAt: playedAt ?? this.playedAt,
      );
  PlayHistoryData copyWithCompanion(PlayHistoryCompanion data) {
    return PlayHistoryData(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryData(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, songId, playedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayHistoryData &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.playedAt == this.playedAt);
}

class PlayHistoryCompanion extends UpdateCompanion<PlayHistoryData> {
  final Value<int> id;
  final Value<int> songId;
  final Value<DateTime> playedAt;
  const PlayHistoryCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.playedAt = const Value.absent(),
  });
  PlayHistoryCompanion.insert({
    this.id = const Value.absent(),
    required int songId,
    required DateTime playedAt,
  })  : songId = Value(songId),
        playedAt = Value(playedAt);
  static Insertable<PlayHistoryData> custom({
    Expression<int>? id,
    Expression<int>? songId,
    Expression<DateTime>? playedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (playedAt != null) 'played_at': playedAt,
    });
  }

  PlayHistoryCompanion copyWith(
      {Value<int>? id, Value<int>? songId, Value<DateTime>? playedAt}) {
    return PlayHistoryCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      playedAt: playedAt ?? this.playedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<int>(songId.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dateCreatedMeta =
      const VerificationMeta('dateCreated');
  @override
  late final GeneratedColumn<DateTime> dateCreated = GeneratedColumn<DateTime>(
      'date_created', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _dateModifiedMeta =
      const VerificationMeta('dateModified');
  @override
  late final GeneratedColumn<DateTime> dateModified = GeneratedColumn<DateTime>(
      'date_modified', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, description, dateCreated, dateModified];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(Insertable<Playlist> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('date_created')) {
      context.handle(
          _dateCreatedMeta,
          dateCreated.isAcceptableOrUnknown(
              data['date_created']!, _dateCreatedMeta));
    } else if (isInserting) {
      context.missing(_dateCreatedMeta);
    }
    if (data.containsKey('date_modified')) {
      context.handle(
          _dateModifiedMeta,
          dateModified.isAcceptableOrUnknown(
              data['date_modified']!, _dateModifiedMeta));
    } else if (isInserting) {
      context.missing(_dateModifiedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      dateCreated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_created'])!,
      dateModified: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}date_modified'])!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final int id;
  final String name;
  final String? description;
  final DateTime dateCreated;
  final DateTime dateModified;
  const Playlist(
      {required this.id,
      required this.name,
      this.description,
      required this.dateCreated,
      required this.dateModified});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['date_created'] = Variable<DateTime>(dateCreated);
    map['date_modified'] = Variable<DateTime>(dateModified);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      dateCreated: Value(dateCreated),
      dateModified: Value(dateModified),
    );
  }

  factory Playlist.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      dateCreated: serializer.fromJson<DateTime>(json['dateCreated']),
      dateModified: serializer.fromJson<DateTime>(json['dateModified']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'dateCreated': serializer.toJson<DateTime>(dateCreated),
      'dateModified': serializer.toJson<DateTime>(dateModified),
    };
  }

  Playlist copyWith(
          {int? id,
          String? name,
          Value<String?> description = const Value.absent(),
          DateTime? dateCreated,
          DateTime? dateModified}) =>
      Playlist(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        dateCreated: dateCreated ?? this.dateCreated,
        dateModified: dateModified ?? this.dateModified,
      );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      dateCreated:
          data.dateCreated.present ? data.dateCreated.value : this.dateCreated,
      dateModified: data.dateModified.present
          ? data.dateModified.value
          : this.dateModified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('dateCreated: $dateCreated, ')
          ..write('dateModified: $dateModified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, dateCreated, dateModified);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.dateCreated == this.dateCreated &&
          other.dateModified == this.dateModified);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<DateTime> dateCreated;
  final Value<DateTime> dateModified;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.dateCreated = const Value.absent(),
    this.dateModified = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    required DateTime dateCreated,
    required DateTime dateModified,
  })  : name = Value(name),
        dateCreated = Value(dateCreated),
        dateModified = Value(dateModified);
  static Insertable<Playlist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<DateTime>? dateCreated,
    Expression<DateTime>? dateModified,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (dateCreated != null) 'date_created': dateCreated,
      if (dateModified != null) 'date_modified': dateModified,
    });
  }

  PlaylistsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<DateTime>? dateCreated,
      Value<DateTime>? dateModified}) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (dateCreated.present) {
      map['date_created'] = Variable<DateTime>(dateCreated.value);
    }
    if (dateModified.present) {
      map['date_modified'] = Variable<DateTime>(dateModified.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('dateCreated: $dateCreated, ')
          ..write('dateModified: $dateModified')
          ..write(')'))
        .toString();
  }
}

class $PlaylistSongsTable extends PlaylistSongs
    with TableInfo<$PlaylistSongsTable, PlaylistSong> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistSongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _playlistIdMeta =
      const VerificationMeta('playlistId');
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
      'playlist_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<int> songId = GeneratedColumn<int>(
      'song_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, playlistId, songId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_songs';
  @override
  VerificationContext validateIntegrity(Insertable<PlaylistSong> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
          _playlistIdMeta,
          playlistId.isAcceptableOrUnknown(
              data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta,
          songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistSong map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistSong(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      playlistId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}playlist_id'])!,
      songId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}song_id'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
    );
  }

  @override
  $PlaylistSongsTable createAlias(String alias) {
    return $PlaylistSongsTable(attachedDatabase, alias);
  }
}

class PlaylistSong extends DataClass implements Insertable<PlaylistSong> {
  final int id;
  final int playlistId;
  final int songId;
  final int position;
  const PlaylistSong(
      {required this.id,
      required this.playlistId,
      required this.songId,
      required this.position});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['song_id'] = Variable<int>(songId);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistSongsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistSongsCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      songId: Value(songId),
      position: Value(position),
    );
  }

  factory PlaylistSong.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistSong(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      songId: serializer.fromJson<int>(json['songId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'songId': serializer.toJson<int>(songId),
      'position': serializer.toJson<int>(position),
    };
  }

  PlaylistSong copyWith(
          {int? id, int? playlistId, int? songId, int? position}) =>
      PlaylistSong(
        id: id ?? this.id,
        playlistId: playlistId ?? this.playlistId,
        songId: songId ?? this.songId,
        position: position ?? this.position,
      );
  PlaylistSong copyWithCompanion(PlaylistSongsCompanion data) {
    return PlaylistSong(
      id: data.id.present ? data.id.value : this.id,
      playlistId:
          data.playlistId.present ? data.playlistId.value : this.playlistId,
      songId: data.songId.present ? data.songId.value : this.songId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistSong(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('songId: $songId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, playlistId, songId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistSong &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.songId == this.songId &&
          other.position == this.position);
}

class PlaylistSongsCompanion extends UpdateCompanion<PlaylistSong> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<int> songId;
  final Value<int> position;
  const PlaylistSongsCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.songId = const Value.absent(),
    this.position = const Value.absent(),
  });
  PlaylistSongsCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required int songId,
    required int position,
  })  : playlistId = Value(playlistId),
        songId = Value(songId),
        position = Value(position);
  static Insertable<PlaylistSong> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<int>? songId,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (songId != null) 'song_id': songId,
      if (position != null) 'position': position,
    });
  }

  PlaylistSongsCompanion copyWith(
      {Value<int>? id,
      Value<int>? playlistId,
      Value<int>? songId,
      Value<int>? position}) {
    return PlaylistSongsCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      songId: songId ?? this.songId,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<int>(songId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistSongsCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('songId: $songId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $LyricsTable extends Lyrics with TableInfo<$LyricsTable, Lyric> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<int> songId = GeneratedColumn<int>(
      'song_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
      'format', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, songId, content, format, syncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics';
  @override
  VerificationContext validateIntegrity(Insertable<Lyric> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta,
          songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('format')) {
      context.handle(_formatMeta,
          format.isAcceptableOrUnknown(data['format']!, _formatMeta));
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Lyric map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Lyric(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      songId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}song_id'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      format: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}format'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
    );
  }

  @override
  $LyricsTable createAlias(String alias) {
    return $LyricsTable(attachedDatabase, alias);
  }
}

class Lyric extends DataClass implements Insertable<Lyric> {
  final int id;
  final int songId;
  final String content;
  final String format;
  final DateTime syncedAt;
  const Lyric(
      {required this.id,
      required this.songId,
      required this.content,
      required this.format,
      required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['song_id'] = Variable<int>(songId);
    map['content'] = Variable<String>(content);
    map['format'] = Variable<String>(format);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  LyricsCompanion toCompanion(bool nullToAbsent) {
    return LyricsCompanion(
      id: Value(id),
      songId: Value(songId),
      content: Value(content),
      format: Value(format),
      syncedAt: Value(syncedAt),
    );
  }

  factory Lyric.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Lyric(
      id: serializer.fromJson<int>(json['id']),
      songId: serializer.fromJson<int>(json['songId']),
      content: serializer.fromJson<String>(json['content']),
      format: serializer.fromJson<String>(json['format']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'songId': serializer.toJson<int>(songId),
      'content': serializer.toJson<String>(content),
      'format': serializer.toJson<String>(format),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  Lyric copyWith(
          {int? id,
          int? songId,
          String? content,
          String? format,
          DateTime? syncedAt}) =>
      Lyric(
        id: id ?? this.id,
        songId: songId ?? this.songId,
        content: content ?? this.content,
        format: format ?? this.format,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  Lyric copyWithCompanion(LyricsCompanion data) {
    return Lyric(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      content: data.content.present ? data.content.value : this.content,
      format: data.format.present ? data.format.value : this.format,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Lyric(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('content: $content, ')
          ..write('format: $format, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, songId, content, format, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lyric &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.content == this.content &&
          other.format == this.format &&
          other.syncedAt == this.syncedAt);
}

class LyricsCompanion extends UpdateCompanion<Lyric> {
  final Value<int> id;
  final Value<int> songId;
  final Value<String> content;
  final Value<String> format;
  final Value<DateTime> syncedAt;
  const LyricsCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.content = const Value.absent(),
    this.format = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  LyricsCompanion.insert({
    this.id = const Value.absent(),
    required int songId,
    required String content,
    required String format,
    required DateTime syncedAt,
  })  : songId = Value(songId),
        content = Value(content),
        format = Value(format),
        syncedAt = Value(syncedAt);
  static Insertable<Lyric> custom({
    Expression<int>? id,
    Expression<int>? songId,
    Expression<String>? content,
    Expression<String>? format,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (content != null) 'content': content,
      if (format != null) 'format': format,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  LyricsCompanion copyWith(
      {Value<int>? id,
      Value<int>? songId,
      Value<String>? content,
      Value<String>? format,
      Value<DateTime>? syncedAt}) {
    return LyricsCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      content: content ?? this.content,
      format: format ?? this.format,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<int>(songId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('content: $content, ')
          ..write('format: $format, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SongsTable songs = $SongsTable(this);
  late final $PlayHistoryTable playHistory = $PlayHistoryTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistSongsTable playlistSongs = $PlaylistSongsTable(this);
  late final $LyricsTable lyrics = $LyricsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [songs, playHistory, playlists, playlistSongs, lyrics, settings];
}

typedef $$SongsTableCreateCompanionBuilder = SongsCompanion Function({
  Value<int> id,
  required String title,
  required String artist,
  required String album,
  required String filePath,
  required int duration,
  Value<int?> fileSize,
  required DateTime dateModified,
  Value<String?> genre,
  Value<String?> albumArtist,
  Value<String?> albumArt,
  Value<int> playCount,
  Value<DateTime?> lastPlayedAt,
  Value<String?> source,
  Value<String?> audioQuality,
});
typedef $$SongsTableUpdateCompanionBuilder = SongsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> artist,
  Value<String> album,
  Value<String> filePath,
  Value<int> duration,
  Value<int?> fileSize,
  Value<DateTime> dateModified,
  Value<String?> genre,
  Value<String?> albumArtist,
  Value<String?> albumArt,
  Value<int> playCount,
  Value<DateTime?> lastPlayedAt,
  Value<String?> source,
  Value<String?> audioQuality,
});

class $$SongsTableFilterComposer extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dateModified => $composableBuilder(
      column: $table.dateModified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get genre => $composableBuilder(
      column: $table.genre, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get albumArtist => $composableBuilder(
      column: $table.albumArtist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get albumArt => $composableBuilder(
      column: $table.albumArt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get playCount => $composableBuilder(
      column: $table.playCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
      column: $table.lastPlayedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioQuality => $composableBuilder(
      column: $table.audioQuality, builder: (column) => ColumnFilters(column));
}

class $$SongsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateModified => $composableBuilder(
      column: $table.dateModified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get genre => $composableBuilder(
      column: $table.genre, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get albumArtist => $composableBuilder(
      column: $table.albumArtist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get albumArt => $composableBuilder(
      column: $table.albumArt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get playCount => $composableBuilder(
      column: $table.playCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
      column: $table.lastPlayedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioQuality => $composableBuilder(
      column: $table.audioQuality,
      builder: (column) => ColumnOrderings(column));
}

class $$SongsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<DateTime> get dateModified => $composableBuilder(
      column: $table.dateModified, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get albumArtist => $composableBuilder(
      column: $table.albumArtist, builder: (column) => column);

  GeneratedColumn<String> get albumArt =>
      $composableBuilder(column: $table.albumArt, builder: (column) => column);

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
      column: $table.lastPlayedAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get audioQuality => $composableBuilder(
      column: $table.audioQuality, builder: (column) => column);
}

class $$SongsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SongsTable,
    Song,
    $$SongsTableFilterComposer,
    $$SongsTableOrderingComposer,
    $$SongsTableAnnotationComposer,
    $$SongsTableCreateCompanionBuilder,
    $$SongsTableUpdateCompanionBuilder,
    (Song, BaseReferences<_$AppDatabase, $SongsTable, Song>),
    Song,
    PrefetchHooks Function()> {
  $$SongsTableTableManager(_$AppDatabase db, $SongsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> artist = const Value.absent(),
            Value<String> album = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<int> duration = const Value.absent(),
            Value<int?> fileSize = const Value.absent(),
            Value<DateTime> dateModified = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<String?> albumArtist = const Value.absent(),
            Value<String?> albumArt = const Value.absent(),
            Value<int> playCount = const Value.absent(),
            Value<DateTime?> lastPlayedAt = const Value.absent(),
            Value<String?> source = const Value.absent(),
            Value<String?> audioQuality = const Value.absent(),
          }) =>
              SongsCompanion(
            id: id,
            title: title,
            artist: artist,
            album: album,
            filePath: filePath,
            duration: duration,
            fileSize: fileSize,
            dateModified: dateModified,
            genre: genre,
            albumArtist: albumArtist,
            albumArt: albumArt,
            playCount: playCount,
            lastPlayedAt: lastPlayedAt,
            source: source,
            audioQuality: audioQuality,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String title,
            required String artist,
            required String album,
            required String filePath,
            required int duration,
            Value<int?> fileSize = const Value.absent(),
            required DateTime dateModified,
            Value<String?> genre = const Value.absent(),
            Value<String?> albumArtist = const Value.absent(),
            Value<String?> albumArt = const Value.absent(),
            Value<int> playCount = const Value.absent(),
            Value<DateTime?> lastPlayedAt = const Value.absent(),
            Value<String?> source = const Value.absent(),
            Value<String?> audioQuality = const Value.absent(),
          }) =>
              SongsCompanion.insert(
            id: id,
            title: title,
            artist: artist,
            album: album,
            filePath: filePath,
            duration: duration,
            fileSize: fileSize,
            dateModified: dateModified,
            genre: genre,
            albumArtist: albumArtist,
            albumArt: albumArt,
            playCount: playCount,
            lastPlayedAt: lastPlayedAt,
            source: source,
            audioQuality: audioQuality,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SongsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SongsTable,
    Song,
    $$SongsTableFilterComposer,
    $$SongsTableOrderingComposer,
    $$SongsTableAnnotationComposer,
    $$SongsTableCreateCompanionBuilder,
    $$SongsTableUpdateCompanionBuilder,
    (Song, BaseReferences<_$AppDatabase, $SongsTable, Song>),
    Song,
    PrefetchHooks Function()>;
typedef $$PlayHistoryTableCreateCompanionBuilder = PlayHistoryCompanion
    Function({
  Value<int> id,
  required int songId,
  required DateTime playedAt,
});
typedef $$PlayHistoryTableUpdateCompanionBuilder = PlayHistoryCompanion
    Function({
  Value<int> id,
  Value<int> songId,
  Value<DateTime> playedAt,
});

class $$PlayHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
      column: $table.playedAt, builder: (column) => ColumnFilters(column));
}

class $$PlayHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
      column: $table.playedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlayHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);
}

class $$PlayHistoryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlayHistoryTable,
    PlayHistoryData,
    $$PlayHistoryTableFilterComposer,
    $$PlayHistoryTableOrderingComposer,
    $$PlayHistoryTableAnnotationComposer,
    $$PlayHistoryTableCreateCompanionBuilder,
    $$PlayHistoryTableUpdateCompanionBuilder,
    (
      PlayHistoryData,
      BaseReferences<_$AppDatabase, $PlayHistoryTable, PlayHistoryData>
    ),
    PlayHistoryData,
    PrefetchHooks Function()> {
  $$PlayHistoryTableTableManager(_$AppDatabase db, $PlayHistoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> songId = const Value.absent(),
            Value<DateTime> playedAt = const Value.absent(),
          }) =>
              PlayHistoryCompanion(
            id: id,
            songId: songId,
            playedAt: playedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int songId,
            required DateTime playedAt,
          }) =>
              PlayHistoryCompanion.insert(
            id: id,
            songId: songId,
            playedAt: playedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlayHistoryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlayHistoryTable,
    PlayHistoryData,
    $$PlayHistoryTableFilterComposer,
    $$PlayHistoryTableOrderingComposer,
    $$PlayHistoryTableAnnotationComposer,
    $$PlayHistoryTableCreateCompanionBuilder,
    $$PlayHistoryTableUpdateCompanionBuilder,
    (
      PlayHistoryData,
      BaseReferences<_$AppDatabase, $PlayHistoryTable, PlayHistoryData>
    ),
    PlayHistoryData,
    PrefetchHooks Function()>;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> description,
  required DateTime dateCreated,
  required DateTime dateModified,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> description,
  Value<DateTime> dateCreated,
  Value<DateTime> dateModified,
});

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dateCreated => $composableBuilder(
      column: $table.dateCreated, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dateModified => $composableBuilder(
      column: $table.dateModified, builder: (column) => ColumnFilters(column));
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateCreated => $composableBuilder(
      column: $table.dateCreated, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateModified => $composableBuilder(
      column: $table.dateModified,
      builder: (column) => ColumnOrderings(column));
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get dateCreated => $composableBuilder(
      column: $table.dateCreated, builder: (column) => column);

  GeneratedColumn<DateTime> get dateModified => $composableBuilder(
      column: $table.dateModified, builder: (column) => column);
}

class $$PlaylistsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaylistsTable,
    Playlist,
    $$PlaylistsTableFilterComposer,
    $$PlaylistsTableOrderingComposer,
    $$PlaylistsTableAnnotationComposer,
    $$PlaylistsTableCreateCompanionBuilder,
    $$PlaylistsTableUpdateCompanionBuilder,
    (Playlist, BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist>),
    Playlist,
    PrefetchHooks Function()> {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime> dateCreated = const Value.absent(),
            Value<DateTime> dateModified = const Value.absent(),
          }) =>
              PlaylistsCompanion(
            id: id,
            name: name,
            description: description,
            dateCreated: dateCreated,
            dateModified: dateModified,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> description = const Value.absent(),
            required DateTime dateCreated,
            required DateTime dateModified,
          }) =>
              PlaylistsCompanion.insert(
            id: id,
            name: name,
            description: description,
            dateCreated: dateCreated,
            dateModified: dateModified,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlaylistsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaylistsTable,
    Playlist,
    $$PlaylistsTableFilterComposer,
    $$PlaylistsTableOrderingComposer,
    $$PlaylistsTableAnnotationComposer,
    $$PlaylistsTableCreateCompanionBuilder,
    $$PlaylistsTableUpdateCompanionBuilder,
    (Playlist, BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist>),
    Playlist,
    PrefetchHooks Function()>;
typedef $$PlaylistSongsTableCreateCompanionBuilder = PlaylistSongsCompanion
    Function({
  Value<int> id,
  required int playlistId,
  required int songId,
  required int position,
});
typedef $$PlaylistSongsTableUpdateCompanionBuilder = PlaylistSongsCompanion
    Function({
  Value<int> id,
  Value<int> playlistId,
  Value<int> songId,
  Value<int> position,
});

class $$PlaylistSongsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistSongsTable> {
  $$PlaylistSongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));
}

class $$PlaylistSongsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistSongsTable> {
  $$PlaylistSongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));
}

class $$PlaylistSongsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistSongsTable> {
  $$PlaylistSongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => column);

  GeneratedColumn<int> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$PlaylistSongsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaylistSongsTable,
    PlaylistSong,
    $$PlaylistSongsTableFilterComposer,
    $$PlaylistSongsTableOrderingComposer,
    $$PlaylistSongsTableAnnotationComposer,
    $$PlaylistSongsTableCreateCompanionBuilder,
    $$PlaylistSongsTableUpdateCompanionBuilder,
    (
      PlaylistSong,
      BaseReferences<_$AppDatabase, $PlaylistSongsTable, PlaylistSong>
    ),
    PlaylistSong,
    PrefetchHooks Function()> {
  $$PlaylistSongsTableTableManager(_$AppDatabase db, $PlaylistSongsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistSongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistSongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistSongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> playlistId = const Value.absent(),
            Value<int> songId = const Value.absent(),
            Value<int> position = const Value.absent(),
          }) =>
              PlaylistSongsCompanion(
            id: id,
            playlistId: playlistId,
            songId: songId,
            position: position,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int playlistId,
            required int songId,
            required int position,
          }) =>
              PlaylistSongsCompanion.insert(
            id: id,
            playlistId: playlistId,
            songId: songId,
            position: position,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlaylistSongsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaylistSongsTable,
    PlaylistSong,
    $$PlaylistSongsTableFilterComposer,
    $$PlaylistSongsTableOrderingComposer,
    $$PlaylistSongsTableAnnotationComposer,
    $$PlaylistSongsTableCreateCompanionBuilder,
    $$PlaylistSongsTableUpdateCompanionBuilder,
    (
      PlaylistSong,
      BaseReferences<_$AppDatabase, $PlaylistSongsTable, PlaylistSong>
    ),
    PlaylistSong,
    PrefetchHooks Function()>;
typedef $$LyricsTableCreateCompanionBuilder = LyricsCompanion Function({
  Value<int> id,
  required int songId,
  required String content,
  required String format,
  required DateTime syncedAt,
});
typedef $$LyricsTableUpdateCompanionBuilder = LyricsCompanion Function({
  Value<int> id,
  Value<int> songId,
  Value<String> content,
  Value<String> format,
  Value<DateTime> syncedAt,
});

class $$LyricsTableFilterComposer
    extends Composer<_$AppDatabase, $LyricsTable> {
  $$LyricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$LyricsTableOrderingComposer
    extends Composer<_$AppDatabase, $LyricsTable> {
  $$LyricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$LyricsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LyricsTable> {
  $$LyricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$LyricsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LyricsTable,
    Lyric,
    $$LyricsTableFilterComposer,
    $$LyricsTableOrderingComposer,
    $$LyricsTableAnnotationComposer,
    $$LyricsTableCreateCompanionBuilder,
    $$LyricsTableUpdateCompanionBuilder,
    (Lyric, BaseReferences<_$AppDatabase, $LyricsTable, Lyric>),
    Lyric,
    PrefetchHooks Function()> {
  $$LyricsTableTableManager(_$AppDatabase db, $LyricsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LyricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LyricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> songId = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> format = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
          }) =>
              LyricsCompanion(
            id: id,
            songId: songId,
            content: content,
            format: format,
            syncedAt: syncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int songId,
            required String content,
            required String format,
            required DateTime syncedAt,
          }) =>
              LyricsCompanion.insert(
            id: id,
            songId: songId,
            content: content,
            format: format,
            syncedAt: syncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LyricsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LyricsTable,
    Lyric,
    $$LyricsTableFilterComposer,
    $$LyricsTableOrderingComposer,
    $$LyricsTableAnnotationComposer,
    $$LyricsTableCreateCompanionBuilder,
    $$LyricsTableUpdateCompanionBuilder,
    (Lyric, BaseReferences<_$AppDatabase, $LyricsTable, Lyric>),
    Lyric,
    PrefetchHooks Function()>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
  $$PlayHistoryTableTableManager get playHistory =>
      $$PlayHistoryTableTableManager(_db, _db.playHistory);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistSongsTableTableManager get playlistSongs =>
      $$PlaylistSongsTableTableManager(_db, _db.playlistSongs);
  $$LyricsTableTableManager get lyrics =>
      $$LyricsTableTableManager(_db, _db.lyrics);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
