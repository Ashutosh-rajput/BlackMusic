import 'dart:async';
import 'package:pixel_player/data/datasources/local/music_local_datasource.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/models/playlist_model.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

abstract class MusicRepository {
  Stream<void> get onLibraryChanged;
  Future<List<Song>> getAllSongs();
  Future<void> addSong(Song song, {bool notify = true});
  Future<void> updateSong(Song song, {bool notify = true});
  Future<void> deleteSong(int songId, {bool notify = true});
  Future<List<Song>> searchSongs(String query);
  Future<void> saveSongsBatch(List<Song> songs, {bool notify = true});

  Future<List<PlaylistModel>> getPlaylists();
  Future<PlaylistModel> createPlaylist(String name, String? description, {bool notify = true});
  Future<void> deletePlaylist(int playlistId, {bool notify = true});
  Future<void> addSongToPlaylist(int playlistId, Song song, {bool notify = true});
  Future<void> removeSongFromPlaylist(int playlistId, int songId, {bool notify = true});
}

class MusicRepositoryImpl implements MusicRepository {
  final MusicLocalDatasource _localDatasource;
  final _libraryChangedController = StreamController<void>.broadcast();

  MusicRepositoryImpl(this._localDatasource);

  @override
  Stream<void> get onLibraryChanged => _libraryChangedController.stream;

  @override
  Future<List<Song>> getAllSongs() async {
    try {
      return await _localDatasource.getAllSongs();
    } catch (e) {
      _logger.e('Error fetching all songs: $e');
      rethrow;
    }
  }

  @override
  Future<void> addSong(Song song, {bool notify = true}) async {
    try {
      await _localDatasource.insertSong(song);
      if (notify) _libraryChangedController.add(null);
    } catch (e) {
      _logger.e('Error adding song: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateSong(Song song, {bool notify = true}) async {
    try {
      await _localDatasource.updateSong(song);
      if (notify) _libraryChangedController.add(null);
    } catch (e) {
      _logger.e('Error updating song: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteSong(int songId, {bool notify = true}) async {
    try {
      await _localDatasource.deleteSong(songId);
      if (notify) _libraryChangedController.add(null);
    } catch (e) {
      _logger.e('Error deleting song: $e');
      rethrow;
    }
  }

  @override
  Future<List<Song>> searchSongs(String query) async {
    try {
      final all = await _localDatasource.getAllSongs();
      final q = query.toLowerCase().trim();
      if (q.isEmpty) return all;
      return all.where((s) =>
        s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q) ||
        s.album.toLowerCase().contains(q)
      ).toList();
    } catch (e) {
      _logger.e('Error searching songs with query "$query": $e');
      rethrow;
    }
  }

  @override
  Future<void> saveSongsBatch(List<Song> songs, {bool notify = true}) async {
    try {
      await _localDatasource.saveSongsBatch(songs);
      if (notify) _libraryChangedController.add(null);
    } catch (e) {
      _logger.e('Error saving songs batch: $e');
      rethrow;
    }
  }

  @override
  Future<List<PlaylistModel>> getPlaylists() async {
    try {
      return await _localDatasource.getPlaylists();
    } catch (e) {
      _logger.e('Error fetching playlists: $e');
      rethrow;
    }
  }

  @override
  Future<PlaylistModel> createPlaylist(String name, String? description, {bool notify = true}) async {
    try {
      final playlist = await _localDatasource.createPlaylist(name, description);
      if (notify) _libraryChangedController.add(null);
      return playlist;
    } catch (e) {
      _logger.e('Error creating playlist "$name": $e');
      rethrow;
    }
  }

  @override
  Future<void> deletePlaylist(int playlistId, {bool notify = true}) async {
    try {
      await _localDatasource.deletePlaylist(playlistId);
      if (notify) _libraryChangedController.add(null);
    } catch (e) {
      _logger.e('Error deleting playlist $playlistId: $e');
      rethrow;
    }
  }

  @override
  Future<void> addSongToPlaylist(int playlistId, Song song, {bool notify = true}) async {
    try {
      await _localDatasource.addSongToPlaylist(playlistId, song);
      if (notify) _libraryChangedController.add(null);
    } catch (e) {
      _logger.e('Error adding song ${song.id} to playlist $playlistId: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeSongFromPlaylist(int playlistId, int songId, {bool notify = true}) async {
    try {
      await _localDatasource.removeSongFromPlaylist(playlistId, songId);
      if (notify) _libraryChangedController.add(null);
    } catch (e) {
      _logger.e('Error removing song $songId from playlist $playlistId: $e');
      rethrow;
    }
  }
}
