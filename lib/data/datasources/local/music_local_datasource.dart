import 'package:drift/drift.dart';
import 'package:pixel_player/data/database/app_database.dart' as db;
import 'package:pixel_player/data/models/song_model.dart';
import 'package:logger/logger.dart';

final logger = Logger();

abstract class MusicLocalDatasource {
  Future<List<Song>> getAllSongs();
  Future<void> insertSong(Song song);
  Future<void> updateSong(Song song);
  Future<void> deleteSong(int songId);
  Future<void> saveSongsBatch(List<Song> songs);
}

class MusicLocalDatasourceImpl implements MusicLocalDatasource {
  final db.AppDatabase _db;
  final List<Song> _memoryCache = [];

  MusicLocalDatasourceImpl(this._db);

  @override
  Future<List<Song>> getAllSongs() async {
    try {
      final List<db.Song> rows = await _db.getAllSongs();
      if (rows.isNotEmpty) {
        final List<Song> mapped = rows.map((db.Song row) => Song(
          id: row.id,
          title: row.title,
          artist: row.artist,
          album: row.album,
          filePath: row.filePath,
          duration: Duration(milliseconds: row.duration),
          fileSize: row.fileSize,
          dateModified: row.dateModified,
          genre: row.genre,
          albumArtist: row.albumArtist,
          albumArt: row.albumArt,
        )).toList();
        return mapped;
      }
    } catch (e) {
      logger.w('Database query error, returning memory cache: $e');
    }
    return List.unmodifiable(_memoryCache);
  }

  @override
  Future<void> insertSong(Song song) async {
    _memoryCache.removeWhere((s) => s.id == song.id || s.filePath == song.filePath);
    _memoryCache.add(song);
    try {
      await _db.insertSong(
        db.SongsCompanion.insert(
          title: song.title,
          artist: song.artist,
          album: song.album,
          filePath: song.filePath,
          duration: song.duration.inMilliseconds,
          fileSize: Value(song.fileSize),
          dateModified: song.dateModified,
          genre: Value(song.genre),
          albumArtist: Value(song.albumArtist),
          albumArt: Value(song.albumArt),
        ),
      );
    } catch (e) {
      logger.e('Error inserting song to database: $e');
    }
  }

  @override
  Future<void> updateSong(Song song) async {
    await insertSong(song);
  }

  @override
  Future<void> deleteSong(int songId) async {
    _memoryCache.removeWhere((s) => s.id == songId);
    try {
      await _db.deleteSongById(songId);
    } catch (e) {
      logger.e('Error deleting song from database: $e');
    }
  }

  @override
  Future<void> saveSongsBatch(List<Song> songs) async {
    for (final song in songs) {
      await insertSong(song);
    }
  }
}
