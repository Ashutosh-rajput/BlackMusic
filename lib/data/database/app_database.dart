import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

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

  @override
  Set<Column> get primaryKey => {id};
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

@DriftDatabase(tables: [Songs, Playlists, PlaylistSongs, Lyrics, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        // Safe schema migration handling for future upgrades
      },
    );
  }

  // DAO helper methods
  Future<List<Song>> getAllSongs() => select(songs).get();

  Future<int> insertSong(SongsCompanion song) => into(songs).insert(
        song,
        mode: InsertMode.insertOrReplace,
      );

  Future<void> insertSongsBatch(List<SongsCompanion> songCompanions) {
    return batch((b) {
      b.insertAll(songs, songCompanions, mode: InsertMode.insertOrReplace);
    });
  }

  Future<int> updateSongDuration(String filePath, int durationMs) {
    return (update(songs)..where((t) => t.filePath.equals(filePath)))
        .write(SongsCompanion(duration: Value(durationMs)));
  }

  Future<int> updateSongFull(SongsCompanion song) {
    return (update(songs)..where((t) => t.filePath.equals(song.filePath.value)))
        .write(song);
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

  Future<int> deleteSongById(int songId) =>
      (delete(songs)..where((t) => t.id.equals(songId))).go();
}

QueryExecutor _openConnection() {
  if (Platform.isAndroid) {
    applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
  return driftDatabase(
    name: 'pixel_player_db',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
