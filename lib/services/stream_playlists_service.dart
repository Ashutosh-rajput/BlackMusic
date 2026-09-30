import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vinyl/data/models/playlist_model.dart';
import 'package:vinyl/data/models/song_model.dart';

/// Service managing stream-only user playlists, keeping them completely
/// separate from local offline library playlists.
class StreamPlaylistsService {
  static const String _storageFileName = 'stream_playlists.json';
  static StreamPlaylistsService? _instance;
  static StreamPlaylistsService get instance => _instance ??= StreamPlaylistsService();

  final Map<int, PlaylistModel> _playlists = {};
  final _playlistsController = StreamController<List<PlaylistModel>>.broadcast();
  File? _storageFile;
  bool _isInitialized = false;

  StreamPlaylistsService() {
    _instance = this;
  }

  Stream<List<PlaylistModel>> get onPlaylistsChanged => _playlistsController.stream;
  List<PlaylistModel> get playlists => _playlists.values.toList()
    ..sort((a, b) => b.dateModified.compareTo(a.dateModified));
  int get count => _playlists.length;

  Future<File> _resolveStorageFile() async {
    if (_storageFile != null) return _storageFile!;
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory.systemTemp;
    }
    _storageFile = File('${baseDir.path}/$_storageFileName');
    return _storageFile!;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _resolveStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                try {
                  final playlist = PlaylistModel.fromJson(item);
                  _playlists[playlist.id] = playlist;
                } catch (_) {}
              }
            }
          }
        }
      }
      _isInitialized = true;
      _notify();
    } catch (e) {
      debugPrint('StreamPlaylistsService init error: $e');
    }
  }

  PlaylistModel? getPlaylist(int id) => _playlists[id];

  bool isSongInPlaylist(int playlistId, int songId) {
    final playlist = _playlists[playlistId];
    if (playlist == null) return false;
    return playlist.songs.any((s) => s.id == songId);
  }

  Future<PlaylistModel> createPlaylist(String name, {String? description}) async {
    final now = DateTime.now();
    final newId = now.millisecondsSinceEpoch;
    final playlist = PlaylistModel(
      id: newId,
      name: name.trim(),
      description: description?.trim(),
      dateCreated: now,
      dateModified: now,
      songs: const [],
    );
    _playlists[newId] = playlist;
    await _saveToFile();
    _notify();
    return playlist;
  }

  Future<bool> addSongToPlaylist(int playlistId, Song song) async {
    final playlist = _playlists[playlistId];
    if (playlist == null) return false;

    // Check if song already exists in this playlist
    if (playlist.songs.any((s) => s.id == song.id)) {
      return false;
    }

    final updatedSongs = List<Song>.from(playlist.songs)..add(song);
    _playlists[playlistId] = playlist.copyWith(
      songs: updatedSongs,
      dateModified: DateTime.now(),
    );

    await _saveToFile();
    _notify();
    return true;
  }

  Future<bool> removeSongFromPlaylist(int playlistId, int songId) async {
    final playlist = _playlists[playlistId];
    if (playlist == null) return false;

    final updatedSongs = playlist.songs.where((s) => s.id != songId).toList();
    _playlists[playlistId] = playlist.copyWith(
      songs: updatedSongs,
      dateModified: DateTime.now(),
    );

    await _saveToFile();
    _notify();
    return true;
  }

  Future<bool> deletePlaylist(int playlistId) async {
    if (_playlists.containsKey(playlistId)) {
      _playlists.remove(playlistId);
      await _saveToFile();
      _notify();
      return true;
    }
    return false;
  }

  Future<bool> renamePlaylist(int playlistId, String newName) async {
    final playlist = _playlists[playlistId];
    if (playlist == null) return false;

    _playlists[playlistId] = playlist.copyWith(
      name: newName.trim(),
      dateModified: DateTime.now(),
    );

    await _saveToFile();
    _notify();
    return true;
  }

  @visibleForTesting
  Future<void> clearForTesting() async {
    _playlists.clear();
    _isInitialized = false;
    final file = await _resolveStorageFile();
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  void _notify() {
    if (!_playlistsController.isClosed) {
      _playlistsController.add(playlists);
    }
  }

  Future<void> _saveToFile() async {
    try {
      final file = await _resolveStorageFile();
      final jsonList = _playlists.values.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('StreamPlaylistsService save error: $e');
    }
  }
}
