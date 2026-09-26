import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pixel_player/data/models/jiosaavn_item.dart';
import 'package:pixel_player/data/models/playlist_model.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:pixel_player/services/file_service.dart';
import 'package:pixel_player/services/permission_service.dart';
import 'package:pixel_player/services/settings_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:pixel_player/data/models/youtube_video_item.dart';
import 'package:pixel_player/presentation/bloc/library/library_event.dart';
import 'package:pixel_player/presentation/bloc/library/library_state.dart';
import 'package:pixel_player/services/user_taste_service.dart';

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final MusicRepository _repository;
  final FileService _fileService;
  final PermissionService _permissionService;
  final SettingsService? _settingsService;
  StreamSubscription<void>? _librarySubscription;

  Timer? _searchDebounceTimer;

  LibraryBloc({
    required MusicRepository repository,
    required FileService fileService,
    required PermissionService permissionService,
    SettingsService? settingsService,
  })  : _repository = repository,
        _fileService = fileService,
        _permissionService = permissionService,
        _settingsService = settingsService,
        super(const LibraryInitial()) {
    on<LoadLibraryEvent>(_onLoadLibrary);
    on<ScanStorageEvent>(_onScanStorage);
    on<SearchSongsEvent>(_onSearchSongs);
    on<SelectCategoryEvent>(_onSelectCategory);
    on<CreatePlaylistEvent>(_onCreatePlaylist);
    on<DeletePlaylistEvent>(_onDeletePlaylist);
    on<AddSongToPlaylistEvent>(_onAddSongToPlaylist);
    on<RemoveSongFromPlaylistEvent>(_onRemoveSongFromPlaylist);
    on<ToggleFavoriteEvent>(_onToggleFavorite);

    _librarySubscription = _repository.onLibraryChanged.listen((_) {
      add(const LoadLibraryEvent());
    });
  }

  @override
  Future<void> close() {
    _searchDebounceTimer?.cancel();
    _librarySubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadLibrary(
    LoadLibraryEvent event,
    Emitter<LibraryState> emit,
  ) async {
    if (state is! LibraryLoaded) {
      emit(const LibraryLoading());
    }
    try {
      var songs = await _repository.getAllSongs();
      var playlists = await _repository.getPlaylists();
      if (!playlists.any((p) => p.name.toLowerCase() == 'favorites')) {
        await _repository.createPlaylist(
            'Favorites', 'Default favorites playlist', notify: false);
        playlists = await _repository.getPlaylists();
      }
      if (state is LibraryLoaded) {
        final current = state as LibraryLoaded;
        emit(current.copyWith(
          allSongs: songs,
          displayedSongs: songs,
          playlists: playlists,
        ));
      } else {
        emit(LibraryLoaded(
            allSongs: songs, displayedSongs: songs, playlists: playlists));
      }
    } catch (e) {
      if (state is! LibraryLoaded) {
        emit(const LibraryLoaded(allSongs: [], displayedSongs: [], playlists: []));
      }
    }
  }

  Future<void> _onScanStorage(
    ScanStorageEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final currentPlaylists = state is LibraryLoaded
        ? (state as LibraryLoaded).playlists
        : const <PlaylistModel>[];
    emit(const LibraryLoading());
    try {
      await _permissionService.requestMusicPermission();
      final scannedSongs = await _fileService.scanMusicLibrary(
        specificPaths: event.customPaths,
        ignoreShortAudio: event.ignoreShortAudio ?? true,
        showHiddenFiles: event.showHiddenFiles ?? false,
      );
      await _repository.saveSongsBatch(scannedSongs);
      // Reload all songs from repository (includes both scanned and previously saved songs)
      final allSongs = await _repository.getAllSongs();
      emit(LibraryLoaded(
          allSongs: allSongs,
          displayedSongs: allSongs,
          playlists: currentPlaylists));
    } catch (e) {
      emit(LibraryError('Failed to scan storage: $e'));
    }
  }

  Future<void> _onSearchSongs(
    SearchSongsEvent event,
    Emitter<LibraryState> emit,
  ) async {
    if (state is LibraryLoaded) {
      final current = state as LibraryLoaded;
      final q = event.query.trim();

      if (q.isEmpty) {
        emit(current.copyWith(
          searchQuery: '',
          displayedSongs: current.allSongs,
          onlineResults: [],
          jiosaavnResults: [],
          isSearchingOnline: false,
        ));
        return;
      }

      _settingsService?.addSearchQuery(q);

      final filteredLocal = await _repository.searchSongs(q);

      final includeOnline = _settingsService?.includeOnlineResults ?? true;

      emit(current.copyWith(
        searchQuery: q,
        displayedSongs: filteredLocal,
        isSearchingOnline: includeOnline,
        onlineResults: includeOnline ? current.onlineResults : [],
        jiosaavnResults: includeOnline ? current.jiosaavnResults : [],
      ));

      if (includeOnline) {
        _searchDebounceTimer?.cancel();
        final completer = Completer<void>();
        _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
          if (!completer.isCompleted) completer.complete();
        });
        await completer.future;

        if (emit.isDone || state is! LibraryLoaded || (state as LibraryLoaded).searchQuery != q) {
          return;
        }

        // Run YouTube and JioSaavn searches in parallel
        final dio = Dio();
        const jiosaavnBase = 'https://jiosaavn-api-eight-beryl.vercel.app';

        final results = await Future.wait([
          // YouTube search
          () async {
            try {
              final youtube = yt.YoutubeExplode();
              final searchList = await youtube.search.search(q);
              final items = searchList.take(8).map((v) {
                return YouTubeVideoItem(
                  id: v.id.value,
                  title: v.title,
                  author: v.author,
                  duration: v.duration ?? Duration.zero,
                  thumbnailUrl: v.thumbnails.mediumResUrl,
                  url: v.url,
                );
              }).toList();
              youtube.close();
              return items;
            } catch (_) {
              return <YouTubeVideoItem>[];
            }
          }(),

          // JioSaavn songs search
          () async {
            try {
              final response = await dio.get(
                '$jiosaavnBase/api/songs',
                queryParameters: {'q': q},
                options: Options(
                  receiveTimeout: const Duration(seconds: 8),
                  sendTimeout: const Duration(seconds: 8),
                ),
              );
              final data = response.data;
              if (data is Map && data['results'] is List) {
                return (data['results'] as List)
                    .take(6)
                    .map((json) => JioSaavnItem.fromSongJson(Map<String, dynamic>.from(json as Map)))
                    .toList();
              }
            } catch (_) {}
            return <JioSaavnItem>[];
          }(),

          // JioSaavn albums search
          () async {
            try {
              final response = await dio.get(
                '$jiosaavnBase/api/albums',
                queryParameters: {'q': q},
                options: Options(
                  receiveTimeout: const Duration(seconds: 8),
                  sendTimeout: const Duration(seconds: 8),
                ),
              );
              final data = response.data;
              if (data is Map && data['results'] is List) {
                return (data['results'] as List)
                    .take(3)
                    .map((json) => JioSaavnItem.fromAlbumJson(Map<String, dynamic>.from(json as Map)))
                    .toList();
              }
            } catch (_) {}
            return <JioSaavnItem>[];
          }(),
        ]);

        dio.close();

        if (!emit.isDone &&
            state is LibraryLoaded &&
            (state as LibraryLoaded).searchQuery == q) {
          final ytItems = results[0] as List<YouTubeVideoItem>;
          final saavnSongs = results[1] as List<JioSaavnItem>;
          final saavnAlbums = results[2] as List<JioSaavnItem>;

          emit((state as LibraryLoaded).copyWith(
            onlineResults: ytItems,
            jiosaavnResults: [...saavnSongs, ...saavnAlbums],
            isSearchingOnline: false,
          ));
        }
      }
    }
  }

  void _onSelectCategory(
    SelectCategoryEvent event,
    Emitter<LibraryState> emit,
  ) {
    if (state is LibraryLoaded) {
      final current = state as LibraryLoaded;
      emit(current.copyWith(selectedCategory: event.category));
    }
  }

  Future<void> _onCreatePlaylist(
    CreatePlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    if (state is LibraryLoaded) {
      final current = state as LibraryLoaded;
      await _repository.createPlaylist(event.name, event.description, notify: false);
      final updatedPlaylists = await _repository.getPlaylists();
      emit(current.copyWith(playlists: updatedPlaylists));
    }
  }

  Future<void> _onDeletePlaylist(
    DeletePlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    if (state is LibraryLoaded) {
      final current = state as LibraryLoaded;
      await _repository.deletePlaylist(event.playlistId, notify: false);
      final updatedPlaylists = await _repository.getPlaylists();
      emit(current.copyWith(playlists: updatedPlaylists));
    }
  }

  Future<void> _onAddSongToPlaylist(
    AddSongToPlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    if (state is LibraryLoaded) {
      final current = state as LibraryLoaded;
      await _repository.addSongToPlaylist(event.playlistId, event.song, notify: false);
      final updatedPlaylists = await _repository.getPlaylists();
      emit(current.copyWith(playlists: updatedPlaylists));
    }
  }

  Future<void> _onRemoveSongFromPlaylist(
    RemoveSongFromPlaylistEvent event,
    Emitter<LibraryState> emit,
  ) async {
    if (state is LibraryLoaded) {
      final current = state as LibraryLoaded;
      await _repository.removeSongFromPlaylist(event.playlistId, event.songId, notify: false);
      final updatedPlaylists = await _repository.getPlaylists();
      emit(current.copyWith(playlists: updatedPlaylists));
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavoriteEvent event,
    Emitter<LibraryState> emit,
  ) async {
    if (state is LibraryLoaded) {
      final current = state as LibraryLoaded;
      var playlists = current.playlists;
      var favIndex =
          playlists.indexWhere((p) => p.name.toLowerCase() == 'favorites');
      if (favIndex == -1) {
        await _repository.createPlaylist(
            'Favorites', 'Default favorites playlist', notify: false);
        playlists = await _repository.getPlaylists();
        favIndex =
            playlists.indexWhere((p) => p.name.toLowerCase() == 'favorites');
      }

      if (favIndex != -1) {
        final favPlaylist = playlists[favIndex];
        final isFav = favPlaylist.songs.any((s) => s.id == event.song.id);
        if (isFav) {
          await _repository.removeSongFromPlaylist(
              favPlaylist.id, event.song.id, notify: false);
          UserTasteService.instance.onSongFavoriteToggled(event.song, false);
        } else {
          await _repository.addSongToPlaylist(favPlaylist.id, event.song, notify: false);
          UserTasteService.instance.onSongFavoriteToggled(event.song, true);
        }
        final updatedPlaylists = await _repository.getPlaylists();
        emit(current.copyWith(playlists: updatedPlaylists));
      }
    }
  }
}
