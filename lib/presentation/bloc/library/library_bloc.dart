import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pixel_player/data/models/playlist_model.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:pixel_player/services/file_service.dart';
import 'package:pixel_player/services/permission_service.dart';
import 'package:pixel_player/presentation/bloc/library/library_event.dart';
import 'package:pixel_player/presentation/bloc/library/library_state.dart';

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final MusicRepository _repository;
  final FileService _fileService;
  final PermissionService _permissionService;

  LibraryBloc({
    required MusicRepository repository,
    required FileService fileService,
    required PermissionService permissionService,
  })  : _repository = repository,
        _fileService = fileService,
        _permissionService = permissionService,
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
  }

  Future<void> _onLoadLibrary(
    LoadLibraryEvent event,
    Emitter<LibraryState> emit,
  ) async {
    emit(const LibraryLoading());
    try {
      var songs = await _repository.getAllSongs();
      if (songs.isEmpty) {
        songs = FileService.getSeedSongs();
        await _repository.saveSongsBatch(songs);
      }
      var playlists = await _repository.getPlaylists();
      if (!playlists.any((p) => p.name.toLowerCase() == 'favorites')) {
        await _repository.createPlaylist('Favorites', 'Default favorites playlist');
        playlists = await _repository.getPlaylists();
      }
      emit(LibraryLoaded(allSongs: songs, displayedSongs: songs, playlists: playlists));
    } catch (e) {
      final seeds = FileService.getSeedSongs();
      emit(LibraryLoaded(allSongs: seeds, displayedSongs: seeds, playlists: const []));
    }
  }

  Future<void> _onScanStorage(
    ScanStorageEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final currentPlaylists = state is LibraryLoaded ? (state as LibraryLoaded).playlists : const <PlaylistModel>[];
    emit(const LibraryLoading());
    try {
      await _permissionService.requestMusicPermission();
      final scannedSongs = await _fileService.scanMusicLibrary(
        specificPaths: event.customPaths,
      );
      await _repository.saveSongsBatch(scannedSongs);
      // Reload all songs from repository (includes both scanned and previously saved songs)
      final allSongs = await _repository.getAllSongs();
      emit(LibraryLoaded(allSongs: allSongs, displayedSongs: allSongs, playlists: currentPlaylists));
    } catch (e) {
      emit(LibraryError('Failed to scan storage: $e'));
    }
  }

  void _onSearchSongs(
    SearchSongsEvent event,
    Emitter<LibraryState> emit,
  ) {
    if (state is LibraryLoaded) {
      final current = state as LibraryLoaded;
      final q = event.query.toLowerCase().trim();
      // When query is empty, reuse the same allSongs reference to avoid unnecessary rebuilds
      if (q.isEmpty) {
        emit(current.copyWith(searchQuery: '', displayedSongs: current.allSongs));
        return;
      }
      final filtered = current.allSongs.where((s) {
        return s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q) ||
            s.album.toLowerCase().contains(q);
      }).toList();
      emit(current.copyWith(searchQuery: event.query, displayedSongs: filtered));
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
      await _repository.createPlaylist(event.name, event.description);
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
      await _repository.deletePlaylist(event.playlistId);
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
      await _repository.addSongToPlaylist(event.playlistId, event.song);
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
      await _repository.removeSongFromPlaylist(event.playlistId, event.songId);
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
      var favIndex = playlists.indexWhere((p) => p.name.toLowerCase() == 'favorites');
      if (favIndex == -1) {
        await _repository.createPlaylist('Favorites', 'Default favorites playlist');
        playlists = await _repository.getPlaylists();
        favIndex = playlists.indexWhere((p) => p.name.toLowerCase() == 'favorites');
      }

      if (favIndex != -1) {
        final favPlaylist = playlists[favIndex];
        final isFav = favPlaylist.songs.any((s) => s.id == event.song.id);
        if (isFav) {
          await _repository.removeSongFromPlaylist(favPlaylist.id, event.song.id);
        } else {
          await _repository.addSongToPlaylist(favPlaylist.id, event.song);
        }
        final updatedPlaylists = await _repository.getPlaylists();
        emit(current.copyWith(playlists: updatedPlaylists));
      }
    }
  }
}
