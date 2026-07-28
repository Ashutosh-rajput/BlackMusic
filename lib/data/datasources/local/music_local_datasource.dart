import 'package:drift/drift.dart';
import 'package:pixel_player/data/database/app_database.dart' as db;
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/models/playlist_model.dart';
import 'package:logger/logger.dart';

final logger = Logger();

abstract class MusicLocalDatasource {
  Future<List<Song>> getAllSongs();
  Future<void> insertSong(Song song);
  Future<void> updateSong(Song song);
  Future<void> deleteSong(int songId);
  Future<void> saveSongsBatch(List<Song> songs);

  Future<List<PlaylistModel>> getPlaylists();
  Future<PlaylistModel> createPlaylist(String name, String? description);
  Future<void> deletePlaylist(int playlistId);
  Future<void> addSongToPlaylist(int playlistId, Song song);
  Future<void> removeSongFromPlaylist(int playlistId, int songId);
}

class MusicLocalDatasourceImpl implements MusicLocalDatasource {
  final db.AppDatabase _db;
  final List<Song> _memoryCache = [];
  final List<PlaylistModel> _memoryPlaylists = [];

  MusicLocalDatasourceImpl(this._db);

  bool _isSeedSong(Song song) {
    return song.id == 101 ||
        song.id == 102 ||
        song.id == 103 ||
        song.id == 104 ||
        song.title == 'Kalimba Acoustic' ||
        song.title == 'Sample Track' ||
        song.title == 'Bower Stereo Demo' ||
        song.title == 'FLAC Master Track' ||
        song.filePath.contains('learningcontainer.com') ||
        song.filePath.contains('raw.githubusercontent.com');
  }

  @override
  Future<List<Song>> getAllSongs() async {
    try {
      final List<db.Song> rows = await _db.getAllSongs();
      if (rows.isNotEmpty) {
        final List<Song> mapped = [];
        for (var row in rows) {
          final song = Song(
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
          );
          if (_isSeedSong(song)) {
            _db.deleteSongById(song.id);
          } else {
            mapped.add(song);
          }
        }
        _memoryCache.removeWhere(_isSeedSong);
        return mapped;
      }
    } catch (e) {
      logger.w('Database query error, returning memory cache: $e');
    }
    _memoryCache.removeWhere(_isSeedSong);
    return List.unmodifiable(_memoryCache);
  }

  bool _dbErrorLogged = false;

  @override
  Future<void> insertSong(Song song) async {
    if (_isSeedSong(song)) return;
    _memoryCache.removeWhere((s) => s.id == song.id || s.filePath == song.filePath);
    _memoryCache.add(song);
    try {
      await _db.insertSong(
        db.SongsCompanion.insert(
          id: Value(song.id),
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
      if (!_dbErrorLogged) {
        _dbErrorLogged = true;
        logger.w('Database write unavailable, using memory storage fallback: $e');
      }
    }
  }

  @override
  Future<void> updateSong(Song song) async {
    _memoryCache.removeWhere((s) => s.id == song.id || s.filePath == song.filePath);
    _memoryCache.add(song);
    try {
      await _db.updateSongFull(
        db.SongsCompanion(
          id: Value(song.id),
          title: Value(song.title),
          artist: Value(song.artist),
          album: Value(song.album),
          filePath: Value(song.filePath),
          duration: Value(song.duration.inMilliseconds),
          fileSize: Value(song.fileSize),
          dateModified: Value(song.dateModified),
          genre: Value(song.genre),
          albumArtist: Value(song.albumArtist),
          albumArt: Value(song.albumArt),
        ),
      );
    } catch (e) {
      logger.w('Database update error: $e');
    }
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
    if (songs.isEmpty) return;
    _memoryCache.removeWhere((existing) => songs.any((s) => s.id == existing.id || s.filePath == existing.filePath));
    _memoryCache.addAll(songs);

    try {
      final companions = songs.map((song) => db.SongsCompanion.insert(
        id: Value(song.id),
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
      )).toList();

      await _db.insertSongsBatch(companions);
    } catch (e) {
      logger.e('Error batch saving songs to database: $e');
    }
  }

  @override
  Future<List<PlaylistModel>> getPlaylists() async {
    try {
      final rows = await _db.getAllPlaylists();
      List<PlaylistModel> result = [];
      final allSongs = await getAllSongs();
      final songMap = {for (var s in allSongs) s.id: s};

      for (var row in rows) {
        final songIds = await _db.getSongIdsForPlaylist(row.id);
        final songs = songIds.map((id) => songMap[id]).whereType<Song>().toList();
        result.add(PlaylistModel(
          id: row.id,
          name: row.name,
          description: row.description,
          dateCreated: row.dateCreated,
          dateModified: row.dateModified,
          songs: songs,
        ));
      }
      _memoryPlaylists.clear();
      _memoryPlaylists.addAll(result);
      return result;
    } catch (e) {
      logger.w('Database error loading playlists, returning memory playlists: $e');
      return List.unmodifiable(_memoryPlaylists);
    }
  }

  @override
  Future<PlaylistModel> createPlaylist(String name, String? description) async {
    final now = DateTime.now();
    int newId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      newId = await _db.insertPlaylist(
        db.PlaylistsCompanion.insert(
          name: name,
          description: Value(description),
          dateCreated: now,
          dateModified: now,
        ),
      );
    } catch (e) {
      logger.w('Database error creating playlist, using memory: $e');
    }

    final newPlaylist = PlaylistModel(
      id: newId,
      name: name,
      description: description,
      dateCreated: now,
      dateModified: now,
      songs: const [],
    );

    _memoryPlaylists.add(newPlaylist);
    return newPlaylist;
  }

  @override
  Future<void> deletePlaylist(int playlistId) async {
    _memoryPlaylists.removeWhere((p) => p.id == playlistId);
    try {
      await _db.deletePlaylistSongs(playlistId);
      await _db.deletePlaylistById(playlistId);
    } catch (e) {
      logger.w('Error deleting playlist: $e');
    }
  }

  @override
  Future<void> addSongToPlaylist(int playlistId, Song song) async {
    final idx = _memoryPlaylists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final current = _memoryPlaylists[idx];
      if (!current.songs.any((s) => s.id == song.id)) {
        final updatedSongs = List<Song>.from(current.songs)..add(song);
        _memoryPlaylists[idx] = current.copyWith(songs: updatedSongs);
      }
    }
    try {
      await _db.addSongToPlaylist(playlistId, song.id);
    } catch (e) {
      logger.w('Error adding song to playlist in db: $e');
    }
  }

  @override
  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    final idx = _memoryPlaylists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final current = _memoryPlaylists[idx];
      final updatedSongs = current.songs.where((s) => s.id != songId).toList();
      _memoryPlaylists[idx] = current.copyWith(songs: updatedSongs);
    }
    try {
      await _db.removeSongFromPlaylist(playlistId, songId);
    } catch (e) {
      logger.w('Error removing song from playlist in db: $e');
    }
  }
}
