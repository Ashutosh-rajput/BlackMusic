import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
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

  // DAO helper methods
  Future<List<Song>> getAllSongs() => select(songs).get();

  Future<int> insertSong(SongsCompanion song) => into(songs).insert(
        song,
        mode: InsertMode.insertOrReplace,
      );

  Future<int> insertPlaylist(PlaylistsCompanion playlist) =>
      into(playlists).insert(playlist);

  Future<List<Playlist>> getAllPlaylists() => select(playlists).get();

  Future<int> deleteSongById(int songId) =>
      (delete(songs)..where((t) => t.id.equals(songId))).go();
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'pixel_player_db',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
