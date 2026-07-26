import 'package:flutter_bloc/flutter_bloc.dart';
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
      emit(LibraryLoaded(allSongs: songs, displayedSongs: songs));
    } catch (e) {
      final seeds = FileService.getSeedSongs();
      emit(LibraryLoaded(allSongs: seeds, displayedSongs: seeds));
    }
  }

  Future<void> _onScanStorage(
    ScanStorageEvent event,
    Emitter<LibraryState> emit,
  ) async {
    emit(const LibraryLoading());
    try {
      await _permissionService.requestMusicPermission();
      final scannedSongs = await _fileService.scanMusicLibrary();
      await _repository.saveSongsBatch(scannedSongs);
      emit(LibraryLoaded(allSongs: scannedSongs, displayedSongs: scannedSongs));
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
}
