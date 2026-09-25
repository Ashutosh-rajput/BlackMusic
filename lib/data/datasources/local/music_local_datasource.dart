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
      final List<Song> mapped = [];
      final List<int> seedIdsToDelete = [];

      for (var row in rows) {
        // Skip remote stream URLs from local library listing (stream-only tracks)
        if (row.filePath.startsWith('http://') || row.filePath.startsWith('https://')) {
          continue;
        }

        String? resolvedSource = row.source;
        String? resolvedQuality = row.audioQuality;

        if (resolvedSource == null || resolvedSource == 'local') {
          final lowerPath = row.filePath.toLowerCase();
          if (row.album == 'YouTube Downloads') {
            resolvedSource = 'youtube';
            resolvedQuality ??= 'HD Audio';
          } else if (row.album == 'JioSaavn' ||
              row.genre == 'Downloaded' ||
              lowerPath.contains('blackmusic') ||
              lowerPath.contains('saavn')) {
            resolvedSource = 'jiosaavn';
            resolvedQuality ??= '320 kbps';
          }
        }

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
          playCount: row.playCount,
          lastPlayedAt: row.lastPlayedAt,
          source: resolvedSource,
          audioQuality: resolvedQuality,
        );

        if (resolvedSource != row.source || resolvedQuality != row.audioQuality) {
          _db.updateSongFull(
            db.SongsCompanion(
              id: Value(row.id),
              filePath: Value(row.filePath),
              source: Value(resolvedSource),
              audioQuality: Value(resolvedQuality),
            ),
          );
        }

        if (_isSeedSong(song)) {
          seedIdsToDelete.add(song.id);
        } else {
          mapped.add(song);
        }
      }

      for (final seedId in seedIdsToDelete) {
        try {
          await _db.deleteSongById(seedId);
        } catch (_) {}
      }

      return mapped;
    } catch (e) {
      logger.e('Error fetching all songs from database: $e');
      rethrow;
    }
  }

  @override
  Future<void> insertSong(Song song) async {
    if (_isSeedSong(song)) return;
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
          source: Value(song.source),
          audioQuality: Value(song.audioQuality),
        ),
      );
    } catch (e) {
      logger.e('Error inserting song into database: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateSong(Song song) async {
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
          source: Value(song.source),
          audioQuality: Value(song.audioQuality),
        ),
      );
    } catch (e) {
      logger.e('Error updating song in database: $e');
      rethrow;
    }
  }

  Future<void> recordSongPlay(Song song) async {
    try {
      await _db.recordSongPlay(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        filePath: song.filePath,
        durationMs: song.duration.inMilliseconds,
        albumArt: song.albumArt,
        source: song.source,
        audioQuality: song.audioQuality,
      );
    } catch (e) {
      logger.e('Error recording song play for "${song.title}": $e');
    }
  }

  Future<List<Song>> getLastPlayedStreamSongs({int limit = 50}) async {
    try {
      final rows = await _db.getLastPlayedStreamSongs(limit: limit);
      return rows.map((row) => Song(
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
        playCount: row.playCount,
        lastPlayedAt: row.lastPlayedAt,
        source: row.source,
        audioQuality: row.audioQuality,
      )).toList();
    } catch (e) {
      logger.e('Error fetching last played stream songs: $e');
      return [];
    }
  }

  Future<void> incrementPlayCount(int songId) async {
    try {
      await _db.incrementPlayCount(songId);
    } catch (e) {
      logger.e('Error incrementing play count for song $songId: $e');
    }
  }

  Future<List<Song>> getMostPlayedSongs({int limit = 20}) async {
    try {
      final rows = await _db.getMostPlayedSongs(limit: limit);
      return rows.map((row) => Song(
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
        playCount: row.playCount,
        lastPlayedAt: row.lastPlayedAt,
        source: row.source,
        audioQuality: row.audioQuality,
      )).toList();
    } catch (e) {
      logger.e('Error fetching most played songs: $e');
      return [];
    }
  }

  @override
  Future<void> deleteSong(int songId) async {
    try {
      await _db.deleteSongById(songId);
    } catch (e) {
      logger.e('Error deleting song from database: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveSongsBatch(List<Song> songs) async {
    final validSongs = songs.where((s) => !_isSeedSong(s)).toList();
    if (validSongs.isEmpty) return;

    try {
      // Fetch existing songs from DB to preserve rich metadata (albumArt, etc.)
      final existingRows = await _db.getAllSongs();
      final existingById = <int, db.Song>{};
      final existingByPath = <String, db.Song>{};
      for (final row in existingRows) {
        existingById[row.id] = row;
        existingByPath[row.filePath] = row;
      }

      final companions = validSongs.map((song) {
        // Check if this song already exists in the DB (by id or filePath)
        final existing = existingById[song.id] ?? existingByPath[song.filePath];

        // Preserve existing rich metadata if the scanner didn't provide it
        final mergedAlbumArt = song.albumArt ?? existing?.albumArt;
        final mergedArtist = (song.artist == 'Unknown Artist' && existing != null && existing.artist != 'Unknown Artist')
            ? existing.artist
            : song.artist;
        final mergedAlbum = (song.album == 'Local Music' && existing != null && existing.album != 'Local Music')
            ? existing.album
            : song.album;
        final mergedGenre = song.genre == 'Audio Track'
            ? (existing?.genre ?? song.genre)
            : song.genre;
        final mergedDuration = (song.duration == const Duration(minutes: 3) && existing != null && existing.duration > 0)
            ? existing.duration
            : song.duration.inMilliseconds;

        // Determine merged source: preserve existing non-local source, or detect from folder/album
        String? mergedSource;
        if (existing?.source != null && existing!.source != 'local') {
          mergedSource = existing.source;
        } else if (song.source != null && song.source != 'local') {
          mergedSource = song.source;
        } else {
          final lowerPath = song.filePath.toLowerCase();
          final existingLowerPath = existing?.filePath.toLowerCase() ?? '';
          if (song.album == 'YouTube Downloads' || (existing?.album == 'YouTube Downloads')) {
            mergedSource = 'youtube';
          } else if (song.album == 'JioSaavn' ||
              (existing?.album == 'JioSaavn') ||
              song.genre == 'Downloaded' ||
              (existing?.genre == 'Downloaded') ||
              lowerPath.contains('blackmusic') ||
              existingLowerPath.contains('blackmusic') ||
              lowerPath.contains('saavn') ||
              existingLowerPath.contains('saavn')) {
            mergedSource = 'jiosaavn';
          } else {
            mergedSource = existing?.source ?? song.source ?? 'local';
          }
        }

        String? mergedQuality = existing?.audioQuality ?? song.audioQuality;
        if (mergedQuality == null) {
          if (mergedSource == 'jiosaavn') {
            mergedQuality = '320 kbps';
          } else if (mergedSource == 'youtube') {
            mergedQuality = 'HD Audio';
          }
        }

        return db.SongsCompanion.insert(
          id: Value(song.id),
          title: song.title,
          artist: mergedArtist,
          album: mergedAlbum,
          filePath: song.filePath,
          duration: mergedDuration,
          fileSize: Value(song.fileSize),
          dateModified: song.dateModified,
          genre: Value(mergedGenre),
          albumArtist: Value(song.albumArtist),
          albumArt: Value(mergedAlbumArt),
          source: Value(mergedSource),
          audioQuality: Value(mergedQuality),
          playCount: Value(existing?.playCount ?? song.playCount),
          lastPlayedAt: Value(existing?.lastPlayedAt ?? song.lastPlayedAt),
        );
      }).toList();

      await _db.insertSongsBatch(companions);
    } catch (e) {
      logger.e('Error batch saving songs to database: $e');
      rethrow;
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
      return result;
    } catch (e) {
      logger.e('Error fetching playlists from database: $e');
      rethrow;
    }
  }

  @override
  Future<PlaylistModel> createPlaylist(String name, String? description) async {
    final now = DateTime.now();
    try {
      final newId = await _db.insertPlaylist(
        db.PlaylistsCompanion.insert(
          name: name,
          description: Value(description),
          dateCreated: now,
          dateModified: now,
        ),
      );

      return PlaylistModel(
        id: newId,
        name: name,
        description: description,
        dateCreated: now,
        dateModified: now,
        songs: const [],
      );
    } catch (e) {
      logger.e('Error creating playlist in database: $e');
      rethrow;
    }
  }

  @override
  Future<void> deletePlaylist(int playlistId) async {
    try {
      await _db.deletePlaylistSongs(playlistId);
      await _db.deletePlaylistById(playlistId);
    } catch (e) {
      logger.e('Error deleting playlist from database: $e');
      rethrow;
    }
  }

  @override
  Future<void> addSongToPlaylist(int playlistId, Song song) async {
    try {
      await _db.addSongToPlaylist(playlistId, song.id);
    } catch (e) {
      logger.e('Error adding song to playlist in database: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    try {
      await _db.removeSongFromPlaylist(playlistId, songId);
    } catch (e) {
      logger.e('Error removing song from playlist in database: $e');
      rethrow;
    }
  }
}
