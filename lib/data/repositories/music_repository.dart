import 'dart:async';
import 'package:pixel_player/data/datasources/local/music_local_datasource.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/models/playlist_model.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

abstract class MusicRepository {
  Stream<void> get onLibraryChanged;
  Future<List<Song>> getAllSongs();
  Future<void> addSong(Song song);
  Future<void> updateSong(Song song);
  Future<void> deleteSong(int songId);
  Future<List<Song>> searchSongs(String query);
  Future<void> saveSongsBatch(List<Song> songs);

  Future<List<PlaylistModel>> getPlaylists();
  Future<PlaylistModel> createPlaylist(String name, String? description);
  Future<void> deletePlaylist(int playlistId);
  Future<void> addSongToPlaylist(int playlistId, Song song);
  Future<void> removeSongFromPlaylist(int playlistId, int songId);
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
  Future<void> addSong(Song song) async {
    try {
      await _localDatasource.insertSong(song);
      _libraryChangedController.add(null);
    } catch (e) {
      _logger.e('Error adding song: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateSong(Song song) async {
    try {
      await _localDatasource.updateSong(song);
      _libraryChangedController.add(null);
    } catch (e) {
      _logger.e('Error updating song: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteSong(int songId) async {
    try {
      await _localDatasource.deleteSong(songId);
      _libraryChangedController.add(null);
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
  Future<void> saveSongsBatch(List<Song> songs) async {
    try {
      await _localDatasource.saveSongsBatch(songs);
      _libraryChangedController.add(null);
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
  Future<PlaylistModel> createPlaylist(String name, String? description) async {
    try {
      final playlist = await _localDatasource.createPlaylist(name, description);
      _libraryChangedController.add(null);
      return playlist;
    } catch (e) {
      _logger.e('Error creating playlist "$name": $e');
      rethrow;
    }
  }

  @override
  Future<void> deletePlaylist(int playlistId) async {
    try {
      await _localDatasource.deletePlaylist(playlistId);
      _libraryChangedController.add(null);
    } catch (e) {
      _logger.e('Error deleting playlist $playlistId: $e');
      rethrow;
    }
  }

  @override
  Future<void> addSongToPlaylist(int playlistId, Song song) async {
    try {
      await _localDatasource.addSongToPlaylist(playlistId, song);
      _libraryChangedController.add(null);
    } catch (e) {
      _logger.e('Error adding song ${song.id} to playlist $playlistId: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    try {
      await _localDatasource.removeSongFromPlaylist(playlistId, songId);
      _libraryChangedController.add(null);
    } catch (e) {
      _logger.e('Error removing song $songId from playlist $playlistId: $e');
      rethrow;
    }
  }
}
