import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:vinyl/core/utils/hash_utils.dart';
import 'package:vinyl/core/utils/song_origin.dart';
import 'package:vinyl/data/database/platform_workaround/platform_workaround.dart';

part 'app_database.g.dart';

class Songs extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text()();
  TextColumn get filePath => text().unique()();
  IntColumn get duration => integer()(); // milliseconds
  IntColumn get fileSize => integer().nullable()();
  DateTimeColumn get dateModified => dateTime()();
  TextColumn get genre => text().nullable()();
  TextColumn get albumArtist => text().nullable()();
  TextColumn get albumArt => text().nullable()();

  // Play tracking
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  // Source: 'local', 'youtube', 'jiosaavn'
  TextColumn get source => text().nullable()();
  // Audio quality: '320 kbps', '128 kbps', 'HD Audio', etc.
  TextColumn get audioQuality => text().nullable()();
  // The provider's own id for the song (JioSaavn id). Without it a song read
  // back from the database could only be found again by its NAME, which picks
  // same-titled songs by other artists / in other languages.
  TextColumn get mediaId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PlayHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get songId => integer()();
  DateTimeColumn get playedAt => dateTime()();
}

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get dateCreated => dateTime()();
  DateTimeColumn get dateModified => dateTime()();
}

class PlaylistSongs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId => integer()();
  IntColumn get songId => integer()();
  IntColumn get position => integer()();
}

class Lyrics extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get songId => integer()();
  TextColumn get content => text()();
  TextColumn get format => text()(); // 'lrc', 'plain', 'ttml'
  DateTimeColumn get syncedAt => dateTime()();
}

class Settings extends Table {
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
}

@DriftDatabase(tables: [Songs, PlayHistory, Playlists, PlaylistSongs, Lyrics, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(songs, songs.playCount);
          await m.addColumn(songs, songs.lastPlayedAt);
          await m.addColumn(songs, songs.source);
          await m.addColumn(songs, songs.audioQuality);
          await m.createTable(playHistory);
        }
        if (from < 3) {
          await m.addColumn(songs, songs.mediaId);
        }
      },
    );
  }

  // DAO helper methods
  Future<List<Song>> getAllSongs() => select(songs).get();

  Future<int> insertSong(SongsCompanion song) async {
    Song? existing;
    if (song.id.present) {
      existing = await (select(songs)..where((t) => t.id.equals(song.id.value))).getSingleOrNull();
    }
    if (existing == null && song.filePath.present) {
      existing = await (select(songs)..where((t) => t.filePath.equals(song.filePath.value))).getSingleOrNull();
    }

    final existingSong = existing;
    if (existingSong != null) {
      final existingId = existingSong.id;
      final incomingPlayCount = song.playCount.present ? song.playCount.value : 0;
      final effectivePlayCount = incomingPlayCount > existingSong.playCount
          ? incomingPlayCount
          : existingSong.playCount;

      final effectiveLastPlayedAt = (song.lastPlayedAt.present && song.lastPlayedAt.value != null)
          ? song.lastPlayedAt.value
          : existingSong.lastPlayedAt;

      final updated = song.copyWith(
        id: Value(existingId),
        playCount: Value(effectivePlayCount),
        lastPlayedAt: Value(effectiveLastPlayedAt),
      );

      await (update(songs)..where((t) => t.id.equals(existingId))).write(updated);
      return existingId;
    }

    return into(songs).insert(
      song,
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> insertSongsBatch(List<SongsCompanion> songCompanions) {
    return batch((b) {
      b.insertAll(songs, songCompanions, mode: InsertMode.insertOrReplace);
    });
  }

  Future<int> updateSongFilePath(int id, String filePath) {
    return (update(songs)..where((t) => t.id.equals(id)))
        .write(SongsCompanion(filePath: Value(filePath)));
  }

  Future<int> updateSongFull(SongsCompanion song) {
    return (update(songs)..where((t) => t.filePath.equals(song.filePath.value)))
        .write(song);
  }

  /// Increment play count and set lastPlayedAt for a song
  Future<void> incrementPlayCount(int songId) async {
    final now = DateTime.now();
    final existing = await (select(songs)..where((t) => t.id.equals(songId))).getSingleOrNull();
    final newCount = (existing?.playCount ?? 0) + 1;
    await (update(songs)..where((t) => t.id.equals(songId))).write(
      SongsCompanion(
        playCount: Value(newCount),
        lastPlayedAt: Value(now),
      ),
    );
    // Also record a history entry
    await into(playHistory).insert(
      PlayHistoryCompanion.insert(songId: songId, playedAt: now),
    );
  }

  /// Rows that belong to Stream (web URL, unresolved, or offline stream
  /// cache), mirroring SongOrigin.isStreamPath for SQL.
  Expression<bool> _isStreamRow($SongsTable t) =>
      t.filePath.like('http://%') |
      t.filePath.like('https://%') |
      t.filePath.equals('') |
      t.filePath.like('%/stream_cache/%');

  /// Get most played songs ordered by play count descending.
  /// With [streamOnly], only Stream songs (used to seed Stream recommendations,
  /// which must not be driven by Library files).
  Future<List<Song>> getMostPlayedSongs({int limit = 20, bool streamOnly = false}) {
    return (select(songs)
          ..where((t) => streamOnly
              ? t.playCount.isBiggerThanValue(0) & _isStreamRow(t)
              : t.playCount.isBiggerThanValue(0))
          ..orderBy([(t) => OrderingTerm.desc(t.playCount)])
          ..limit(limit))
        .get();
  }

  /// Record a song play, inserting it if it's a streamed song, and updating lastPlayedAt & playCount
  Future<void> recordSongPlay({
    required int id,
    required String title,
    required String artist,
    required String album,
    required String filePath,
    required int durationMs,
    String? albumArt,
    String? source,
    String? audioQuality,
    String? mediaId,
  }) async {
    final now = DateTime.now();
    // A play is only ever credited to a row from the same side: a Stream play
    // never updates a Library song (or vice versa), even with the same title.
    final playIsStream = SongOrigin.isStreamPath(filePath);
    bool sameSide(Song row) => SongOrigin.isStreamPath(row.filePath) == playIsStream;

    Song? existing;
    try {
      existing = await (select(songs)..where((t) => t.id.equals(id))..limit(1)).getSingleOrNull();
      if (existing != null && !sameSide(existing)) existing = null;
      if (existing == null && filePath.isNotEmpty) {
        existing = await (select(songs)..where((t) => t.filePath.equals(filePath))..limit(1)).getSingleOrNull();
      }
      if (existing == null && title.trim().isNotEmpty && artist.trim().isNotEmpty) {
        final sameTitle = await (select(songs)
              ..where((t) =>
                  t.title.lower().equals(title.toLowerCase().trim()) &
                  t.artist.lower().equals(artist.toLowerCase().trim())))
            .get();
        existing = sameTitle.where(sameSide).firstOrNull;
      }
    } catch (_) {}

    final existingSong = existing;
    var recordedId = existingSong?.id ?? id;
    if (existingSong == null) {
      // If this id is taken by a song from the other side, store the play
      // under a derived id rather than replacing that song.
      var insertId = id;
      final idOwner = await (select(songs)..where((t) => t.id.equals(id))..limit(1)).getSingleOrNull();
      if (idOwner != null && !sameSide(idOwner)) {
        insertId = generateStableId('${playIsStream ? 'stream' : 'library'}:$filePath:$title:$artist');
      }
      recordedId = insertId;
      await into(songs).insert(
        SongsCompanion.insert(
          id: Value(insertId),
          title: title,
          artist: artist,
          album: album,
          filePath: filePath,
          duration: durationMs,
          dateModified: now,
          albumArt: Value(albumArt),
          source: Value(source ?? 'jiosaavn'),
          audioQuality: Value(audioQuality ?? '320 kbps'),
          mediaId: Value(mediaId),
          playCount: const Value(1),
          lastPlayedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );
    } else {
      // Never replace a song's real on-device file with the path being
      // played. Streaming a song that is already downloaded matches the
      // downloaded row (by title + artist); overwriting its local path with
      // the stream URL made the download vanish from the Library, and a
      // stream-cache path would break it once the cache is cleared. Only
      // stream rows (remote or empty path) take the newer path.
      final existingPath = existingSong.filePath.trim();
      final existingIsRemote = existingPath.isEmpty ||
          existingPath.startsWith('http://') ||
          existingPath.startsWith('https://');
      await (update(songs)..where((t) => t.id.equals(existingSong.id))).write(
        SongsCompanion(
          playCount: Value(existingSong.playCount + 1),
          lastPlayedAt: Value(now),
          source: Value(existingSong.source ?? source),
          audioQuality: Value(existingSong.audioQuality ?? audioQuality),
          albumArt: Value(existingSong.albumArt ?? albumArt),
          // Fills in the provider id for rows saved before it was stored.
          mediaId: Value(existingSong.mediaId ?? mediaId),
          filePath: (filePath.isNotEmpty && existingIsRemote) ? Value(filePath) : const Value.absent(),
        ),
      );
    }

    try {
      await into(playHistory).insert(
        PlayHistoryCompanion.insert(songId: recordedId, playedAt: now),
      );
    } catch (_) {}
  }

  /// Get stream songs that were played, ordered by lastPlayedAt descending.
  /// Library songs are excluded: Stream's Last Played, Autoplay and Radio must
  /// only see Stream songs.
  Future<List<Song>> getLastPlayedStreamSongs({int limit = 50}) {
    return (select(songs)
          ..where((t) => t.lastPlayedAt.isNotNull() & _isStreamRow(t))
          ..orderBy([(t) => OrderingTerm.desc(t.lastPlayedAt)])
          ..limit(limit))
        .get();
  }

  /// Get recent play history (distinct songs, ordered by playedAt desc)
  Future<List<PlayHistoryData>> getPlayHistory({int limit = 50}) {
    return (select(playHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
          ..limit(limit))
        .get();
  }

  Future<int> insertPlaylist(PlaylistsCompanion playlist) =>
      into(playlists).insert(playlist);

  Future<List<Playlist>> getAllPlaylists() => select(playlists).get();

  Future<int> deletePlaylistById(int playlistId) =>
      (delete(playlists)..where((t) => t.id.equals(playlistId))).go();

  Future<int> deletePlaylistSongs(int playlistId) =>
      (delete(playlistSongs)..where((t) => t.playlistId.equals(playlistId))).go();

  Future<int> addSongToPlaylist(int playlistId, int songId) async {
    final existing = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId)))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final count = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId)))
        .get()
        .then((l) => l.length);

    return into(playlistSongs).insert(
      PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        position: count,
      ),
    );
  }

  Future<List<int>> getSongIdsForPlaylist(int playlistId) async {
    final rows = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    return rows.map((r) => r.songId).toList();
  }

  Future<int> removeSongFromPlaylist(int playlistId, int songId) {
    return (delete(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId)))
        .go();
  }

  Future<int> deleteSongById(int songId) {
    return transaction(() async {
      await (delete(playlistSongs)..where((t) => t.songId.equals(songId))).go();
      await (delete(lyrics)..where((t) => t.songId.equals(songId))).go();
      await (delete(playHistory)..where((t) => t.songId.equals(songId))).go();
      return (delete(songs)..where((t) => t.id.equals(songId))).go();
    });
  }

  // Lyrics helpers
  Future<Lyric?> getLyricsBySongId(int songId) =>
      (select(lyrics)..where((t) => t.songId.equals(songId))).getSingleOrNull();

  Future<void> saveLyrics({
    required int songId,
    required String content,
    required String format,
  }) async {
    final existing = await getLyricsBySongId(songId);
    if (existing != null) {
      await (update(lyrics)..where((t) => t.id.equals(existing.id))).write(
        LyricsCompanion(
          content: Value(content),
          format: Value(format),
          syncedAt: Value(DateTime.now()),
        ),
      );
    } else {
      await into(lyrics).insert(
        LyricsCompanion.insert(
          songId: songId,
          content: content,
          format: format,
          syncedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<int> deleteLyricsBySongId(int songId) =>
      (delete(lyrics)..where((t) => t.songId.equals(songId))).go();
}


QueryExecutor _openConnection() {
  applyPlatformWorkarounds();
  return driftDatabase(
    name: 'vinyl_db',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
