import 'package:pixel_player/data/datasources/local/music_local_datasource.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/models/playlist_model.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

abstract class MusicRepository {
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

  MusicRepositoryImpl(this._localDatasource);

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
    } catch (e) {
      _logger.e('Error adding song: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateSong(Song song) async {
    try {
      await _localDatasource.updateSong(song);
    } catch (e) {
      _logger.e('Error updating song: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteSong(int songId) async {
    try {
      await _localDatasource.deleteSong(songId);
    } catch (e) {
      _logger.e('Error deleting song: $e');
      rethrow;
    }
  }

  @override
  Future<List<Song>> searchSongs(String query) async {
    try {
      final songs = await _localDatasource.getAllSongs();
      if (query.trim().isEmpty) return songs;
      final q = query.toLowerCase();
      return songs.where((song) {
        return song.title.toLowerCase().contains(q) ||
            song.artist.toLowerCase().contains(q) ||
            song.album.toLowerCase().contains(q);
      }).toList();
    } catch (e) {
      _logger.e('Error searching songs: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveSongsBatch(List<Song> songs) async {
    try {
      await _localDatasource.saveSongsBatch(songs);
    } catch (e) {
      _logger.e('Error batch saving songs: $e');
      rethrow;
    }
  }

  @override
  Future<List<PlaylistModel>> getPlaylists() async {
    return await _localDatasource.getPlaylists();
  }

  @override
  Future<PlaylistModel> createPlaylist(String name, String? description) async {
    return await _localDatasource.createPlaylist(name, description);
  }

  @override
  Future<void> deletePlaylist(int playlistId) async {
    await _localDatasource.deletePlaylist(playlistId);
  }

  @override
  Future<void> addSongToPlaylist(int playlistId, Song song) async {
    await _localDatasource.addSongToPlaylist(playlistId, song);
  }

  @override
  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    await _localDatasource.removeSongFromPlaylist(playlistId, songId);
  }
}
