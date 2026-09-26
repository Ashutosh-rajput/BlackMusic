import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/services/user_taste_service.dart';

/// Service managing stream-only favorite tracks, keeping them completely
/// separate from local offline library favorites.
class StreamFavoritesService {
  static const String _storageFileName = 'stream_favorites.json';
  static StreamFavoritesService? _instance;
  static StreamFavoritesService get instance => _instance ??= StreamFavoritesService();

  final Map<int, Song> _favorites = {};
  final _favoritesController = StreamController<List<Song>>.broadcast();
  File? _storageFile;
  bool _isInitialized = false;

  StreamFavoritesService() {
    _instance = this;
  }

  Stream<List<Song>> get onFavoritesChanged => _favoritesController.stream;
  List<Song> get favorites => _favorites.values.toList();
  int get count => _favorites.length;

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
                  final song = Song.fromJson(item);
                  _favorites[song.id] = song;
                } catch (_) {}
              }
            }
          }
        }
      }
      _isInitialized = true;
      _notify();
    } catch (e) {
      debugPrint('StreamFavoritesService init error: $e');
    }
  }

  bool isFavorite(int songId) => _favorites.containsKey(songId);

  int getSongIdForItem(dynamic item) {
    if (item == null) return 0;
    final idStr = item.id?.toString() ?? '';
    final tokenStr = item.token?.toString() ?? '';
    final parsed = int.tryParse(idStr);
    return parsed ?? (idStr.isNotEmpty ? idStr : tokenStr).hashCode.abs();
  }

  bool isItemFavorite(dynamic item) {
    final sId = getSongIdForItem(item);
    return isFavorite(sId);
  }

  Future<bool> toggleFavorite(Song song) async {
    if (isFavorite(song.id)) {
      _favorites.remove(song.id);
      await _saveToFile();
      _notify();
      UserTasteService.instance.onSongFavoriteToggled(song, false);
      return false;
    } else {
      _favorites[song.id] = song;
      await _saveToFile();
      _notify();
      UserTasteService.instance.onSongFavoriteToggled(song, true);
      return true;
    }
  }

  Future<void> removeFavorite(int songId) async {
    if (_favorites.containsKey(songId)) {
      final song = _favorites.remove(songId);
      await _saveToFile();
      _notify();
      if (song != null) {
        UserTasteService.instance.onSongFavoriteToggled(song, false);
      }
    }
  }

  @visibleForTesting
  Future<void> clearForTesting() async {
    _favorites.clear();
    _isInitialized = false;
    final file = await _resolveStorageFile();
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  void _notify() {
    if (!_favoritesController.isClosed) {
      _favoritesController.add(_favorites.values.toList());
    }
  }

  Future<void> _saveToFile() async {
    try {
      final file = await _resolveStorageFile();
      final jsonList = _favorites.values.map((s) => s.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('StreamFavoritesService save error: $e');
    }
  }
}
