import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart' hide PlayerEvent, PlayerState;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:pixel_player/services/audio_service.dart';
import 'package:pixel_player/services/settings_service.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final AudioPlayerService _audioService;
  final MusicRepository? _repository;
  final SettingsService? _settingsService;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _currentIndexSubscription;

  Song? _currentSong;
  List<Song> _queue = [];
  List<Song> _originalQueue = []; // Preserved for restoring order after shuffle
  bool _isShuffle = false;
  bool _isRepeat = false;
  bool _autoPlayNext = true;
  String _repeatMode = 'Off';
  bool _isChangingSong = false;

  PlayerBloc({
    required AudioPlayerService audioService,
    MusicRepository? repository,
    SettingsService? settingsService,
  })  : _audioService = audioService,
        _repository = repository,
        _settingsService = settingsService,
        super(const PlayerInitial()) {
    _isShuffle = settingsService?.shuffleByDefault ?? false;
    _autoPlayNext = settingsService?.autoPlayNext ?? true;
    _repeatMode = settingsService?.repeatMode ?? 'Off';
    _isRepeat = _repeatMode != 'Off';

    on<PlaySongEvent>(_onPlaySong);
    on<PlayQueueEvent>(_onPlayQueue);
    on<PlaySongAtIndexEvent>(_onPlaySongAtIndex);
    on<InsertNextEvent>(_onInsertNext);
    on<AddToQueueEvent>(_onAddToQueue);
    on<RemoveFromQueueEvent>(_onRemoveFromQueue);
    on<ReorderQueueEvent>(_onReorderQueue);
    on<ClearQueueEvent>(_onClearQueue);
    on<PauseEvent>(_onPause);
    on<ResumeEvent>(_onResume);
    on<StopEvent>(_onStop);
    on<SeekEvent>(_onSeek);
    on<SetVolumeEvent>(_onSetVolume);
    on<SetPlaybackRateEvent>(_onSetPlaybackRate);
    on<NextSongEvent>(_onNextSong);
    on<PreviousSongEvent>(_onPreviousSong);
    on<ToggleShuffleEvent>(_onToggleShuffle);
    on<SetShuffleEvent>(_onSetShuffle);
    on<ToggleRepeatEvent>(_onToggleRepeat);
    on<SetRepeatModeEvent>(_onSetRepeatMode);
    on<SetAutoPlayNextEvent>(_onSetAutoPlayNext);
    on<PositionChangedEvent>(_onPositionChanged);
    on<DurationChangedEvent>(_onDurationChanged);

    _listenToStreams();
  }

  void _listenToStreams() {
    _positionSubscription = _audioService.positionStream.listen((pos) async {
      final dur = _audioService.player.duration;
      if (!_autoPlayNext &&
          !_isChangingSong &&
          _audioService.player.playing &&
          dur != null &&
          dur > Duration.zero &&
          pos >= dur - const Duration(milliseconds: 300)) {
        _isChangingSong = true;
        await _audioService.pause();
        await _audioService.seek(Duration.zero);
        add(const PositionChangedEvent(Duration.zero));
        add(const PauseEvent());
        _isChangingSong = false;
        return;
      }
      add(PositionChangedEvent(pos));
    });

    _durationSubscription = _audioService.durationStream.listen((dur) {
      if (dur != null) {
        add(DurationChangedEvent(dur));
      }
    });

    _currentIndexSubscription = _audioService.player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && !_isChangingSong) {
        final list = _audioService.player.sequenceState.sequence;
        if (index < list.length) {
          final tag = list[index].tag;
          if (tag is MediaItem) {
            final songId = int.tryParse(tag.id);
            if (songId != null) {
              final matchingSong = _queue.firstWhere(
                (s) => s.id == songId,
                orElse: () => _currentSong ?? (_queue.isNotEmpty ? _queue.first : null)!,
              );
              _currentSong = matchingSong;
              return;
            }
          }
        }
        if (index < _queue.length) {
          _currentSong = _queue[index];
        }
      }
    });

    _playerStateSubscription = _audioService.playerStateStream.listen((playerState) async {
      if (playerState.processingState == ProcessingState.ready && playerState.playing) {
        _isChangingSong = false;
      }

      if (_isChangingSong) return; // Prevent race conditions during song switching

      if (playerState.processingState == ProcessingState.completed) {
        final pos = _audioService.player.position;
        final dur = _audioService.player.duration;
        // Only auto-advance if the song actually played to its end
        if (dur != null && dur > Duration.zero && pos >= dur - const Duration(milliseconds: 1000)) {
          _isChangingSong = true;
          if ((_repeatMode == 'One' || _isRepeat) && _currentSong != null) {
            add(PlaySongEvent(_currentSong!));
          } else if (_autoPlayNext) {
            add(const NextSongEvent());
          } else {
            // Stay on current song, pause and seek to 0:00
            await _audioService.pause();
            await _audioService.seek(Duration.zero);
            add(const PauseEvent());
            _isChangingSong = false;
          }
        }
      }
    });
  }

  void _onPositionChanged(PositionChangedEvent event, Emitter<PlayerState> emit) {
    if (state is PlayerPlaying) {
      final current = state as PlayerPlaying;
      emit(current.copyWith(song: _currentSong, position: event.position));
    } else if (state is PlayerPaused) {
      final current = state as PlayerPaused;
      emit(current.copyWith(song: _currentSong, position: event.position));
    } else if (state is PlayerLoading && _currentSong != null) {
      final current = state as PlayerLoading;
      emit(PlayerPlaying(
        song: _currentSong!,
        position: event.position,
        duration: _audioService.player.duration ?? _currentSong!.duration,
        isShuffle: current.isShuffle,
        isRepeat: current.isRepeat,
        queue: _queue,
      ));
    }
  }

  void _onDurationChanged(DurationChangedEvent event, Emitter<PlayerState> emit) {
    if (state is PlayerPlaying) {
      final current = state as PlayerPlaying;
      emit(current.copyWith(song: _currentSong, duration: event.duration));
    } else if (state is PlayerPaused) {
      final current = state as PlayerPaused;
      emit(current.copyWith(song: _currentSong, duration: event.duration));
    } else if (state is PlayerLoading && _currentSong != null) {
      final current = state as PlayerLoading;
      emit(PlayerPlaying(
        song: _currentSong!,
        position: _audioService.player.position,
        duration: event.duration,
        isShuffle: current.isShuffle,
        isRepeat: current.isRepeat,
        queue: _queue,
      ));
    }
  }

  /// Shared internal play method
  Future<void> _playSongInternal(Song song, Emitter<PlayerState> emit) async {
    if (_currentSong?.id == song.id &&
        state is PlayerPlaying &&
        _audioService.player.playing &&
        _audioService.player.processingState != ProcessingState.completed) {
      _isChangingSong = false;
      return;
    }

    try {
      _isChangingSong = true;
      _currentSong = song;
      emit(PlayerLoading(
        song: song,
        isShuffle: _isShuffle,
        isRepeat: _isRepeat,
      ));
      await _audioService.play(song.filePath, songInfo: song);

      final dur = _audioService.player.duration ?? song.duration;
      Song activeSong = song;
      if (dur > Duration.zero && (song.duration == Duration.zero || (song.duration - dur).inSeconds.abs() > 1)) {
        activeSong = song.copyWith(duration: dur);
        _currentSong = activeSong;
        _repository?.updateSong(activeSong);
      }

      emit(PlayerPlaying(
        song: activeSong,
        position: Duration.zero,
        duration: dur,
        isShuffle: _isShuffle,
        isRepeat: _isRepeat,
        queue: _queue,
      ));
      _isChangingSong = false;
    } catch (e) {
      _isChangingSong = false;
      if (e.toString().contains('Loading interrupted')) {
        return;
      }
      emit(PlayerError('Failed to play song: $e'));
    }
  }

  Future<void> _onPlaySong(PlaySongEvent event, Emitter<PlayerState> emit) async {
    if (event.queue != null && event.queue!.isNotEmpty) {
      _queue = List.from(event.queue!);
      _originalQueue = List.from(event.queue!);
      final initialIndex = _queue.indexWhere((s) => s.id == event.song.id);
      if (initialIndex != -1 && _queue.length > 1) {
        _currentSong = event.song;
        emit(PlayerLoading(song: event.song, isShuffle: _isShuffle, isRepeat: _isRepeat));
        await _audioService.playQueue(_queue, initialIndex: initialIndex);
        final dur = _audioService.player.duration ?? event.song.duration;
        emit(PlayerPlaying(
          song: event.song,
          position: Duration.zero,
          duration: dur,
          isShuffle: _isShuffle,
          isRepeat: _isRepeat,
          queue: _queue,
        ));
        _isChangingSong = false;
        return;
      }
    } else if (!_queue.any((s) => s.id == event.song.id)) {
      _queue.add(event.song);
      _originalQueue.add(event.song);
    }
    await _playSongInternal(event.song, emit);
  }

  Future<void> _onPlayQueue(PlayQueueEvent event, Emitter<PlayerState> emit) async {
    if (event.queue.isEmpty) return;
    _queue = List.from(event.queue);
    _originalQueue = List.from(event.queue);

    if (_isShuffle) {
      _queue.shuffle();
    }

    final safeIndex = event.initialIndex.clamp(0, _queue.length - 1);
    _currentSong = _queue[safeIndex];
    emit(PlayerLoading(song: _currentSong, isShuffle: _isShuffle, isRepeat: _isRepeat));

    if (_queue.length > 1) {
      await _audioService.playQueue(_queue, initialIndex: safeIndex);
      final dur = _audioService.player.duration ?? _currentSong!.duration;
      emit(PlayerPlaying(
        song: _currentSong!,
        position: Duration.zero,
        duration: dur,
        isShuffle: _isShuffle,
        isRepeat: _isRepeat,
        queue: _queue,
      ));
      _isChangingSong = false;
    } else {
      await _playSongInternal(_currentSong!, emit);
    }
  }

  Future<void> _onPlaySongAtIndex(PlaySongAtIndexEvent event, Emitter<PlayerState> emit) async {
    if (event.index < 0 || event.index >= _queue.length) return;
    await _playSongInternal(_queue[event.index], emit);
  }

  Future<void> _onInsertNext(InsertNextEvent event, Emitter<PlayerState> emit) async {
    if (_queue.isEmpty) {
      _queue = [event.song];
      _originalQueue = [event.song];
      await _playSongInternal(event.song, emit);
      return;
    }

    final currentIndex = _currentSong != null ? _queue.indexWhere((s) => s.id == _currentSong!.id) : -1;
    final targetIndex = currentIndex != -1 ? currentIndex + 1 : _queue.length;

    // Remove if already in queue to prevent duplicate confusion
    _queue.removeWhere((s) => s.id == event.song.id);
    _originalQueue.removeWhere((s) => s.id == event.song.id);

    final safeTarget = targetIndex.clamp(0, _queue.length);
    _queue.insert(safeTarget, event.song);
    _originalQueue.insert(safeTarget, event.song);

    _emitUpdatedQueueState(emit);
  }

  Future<void> _onAddToQueue(AddToQueueEvent event, Emitter<PlayerState> emit) async {
    if (_queue.isEmpty) {
      _queue = [event.song];
      _originalQueue = [event.song];
      await _playSongInternal(event.song, emit);
      return;
    }

    if (!_queue.any((s) => s.id == event.song.id)) {
      _queue.add(event.song);
      _originalQueue.add(event.song);
    }

    _emitUpdatedQueueState(emit);
  }

  Future<void> _onRemoveFromQueue(RemoveFromQueueEvent event, Emitter<PlayerState> emit) async {
    if (event.index < 0 || event.index >= _queue.length) return;

    final removedSong = _queue.removeAt(event.index);
    _originalQueue.removeWhere((s) => s.id == removedSong.id);

    if (removedSong.id == _currentSong?.id) {
      if (_queue.isNotEmpty) {
        final nextIndex = event.index.clamp(0, _queue.length - 1);
        await _playSongInternal(_queue[nextIndex], emit);
      } else {
        await _onStop(const StopEvent(), emit);
      }
    } else {
      _emitUpdatedQueueState(emit);
    }
  }

  void _onReorderQueue(ReorderQueueEvent event, Emitter<PlayerState> emit) {
    if (event.oldIndex < 0 || event.oldIndex >= _queue.length) return;
    int newIndex = event.newIndex;
    if (newIndex > event.oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, _queue.length - 1);

    final item = _queue.removeAt(event.oldIndex);
    _queue.insert(newIndex, item);

    _emitUpdatedQueueState(emit);
  }

  void _onClearQueue(ClearQueueEvent event, Emitter<PlayerState> emit) {
    _queue.clear();
    _originalQueue.clear();
    if (_currentSong != null) {
      _queue.add(_currentSong!);
      _originalQueue.add(_currentSong!);
    }
    _emitUpdatedQueueState(emit);
  }

  void _emitUpdatedQueueState(Emitter<PlayerState> emit) {
    if (state is PlayerPlaying) {
      emit((state as PlayerPlaying).copyWith(
        queue: List.from(_queue),
        isShuffle: _isShuffle,
        isRepeat: _isRepeat,
        repeatMode: _repeatMode,
      ));
    } else if (state is PlayerPaused) {
      emit((state as PlayerPaused).copyWith(
        queue: List.from(_queue),
        isShuffle: _isShuffle,
        isRepeat: _isRepeat,
        repeatMode: _repeatMode,
      ));
    }
  }

  Future<void> _onPause(PauseEvent event, Emitter<PlayerState> emit) async {
    try {
      await _audioService.pause();
      if (state is PlayerPlaying) {
        final playing = state as PlayerPlaying;
        emit(PlayerPaused(
          song: _currentSong ?? playing.song,
          position: playing.position,
          duration: playing.duration,
          volume: playing.volume,
          playbackRate: playing.playbackRate,
          isShuffle: playing.isShuffle,
          isRepeat: playing.isRepeat,
          repeatMode: playing.repeatMode,
          queue: playing.queue,
        ));
      }
    } catch (e) {
      emit(PlayerError('Failed to pause: $e'));
    }
  }

  Future<void> _onResume(ResumeEvent event, Emitter<PlayerState> emit) async {
    try {
      await _audioService.resume();
      if (state is PlayerPaused) {
        final paused = state as PlayerPaused;
        emit(PlayerPlaying(
          song: paused.song,
          position: paused.position,
          duration: paused.duration,
          volume: paused.volume,
          playbackRate: paused.playbackRate,
          isShuffle: paused.isShuffle,
          isRepeat: paused.isRepeat,
          queue: paused.queue,
        ));
      } else if (_currentSong != null) {
        await _playSongInternal(_currentSong!, emit);
      }
    } catch (e) {
      emit(PlayerError('Failed to resume: $e'));
    }
  }

  Future<void> _onStop(StopEvent event, Emitter<PlayerState> emit) async {
    try {
      await _audioService.stop();
      emit(const PlayerStopped());
    } catch (e) {
      emit(PlayerError('Failed to stop: $e'));
    }
  }

  Future<void> _onSeek(SeekEvent event, Emitter<PlayerState> emit) async {
    try {
      await _audioService.seek(event.position);
      if (state is PlayerPlaying) {
        final playing = state as PlayerPlaying;
        emit(playing.copyWith(position: event.position));
      } else if (state is PlayerPaused) {
        final paused = state as PlayerPaused;
        emit(paused.copyWith(position: event.position));
      }
    } catch (e) {
      emit(PlayerError('Failed to seek: $e'));
    }
  }

  Future<void> _onSetVolume(SetVolumeEvent event, Emitter<PlayerState> emit) async {
    try {
      await _audioService.setVolume(event.volume);
      if (state is PlayerPlaying) {
        final playing = state as PlayerPlaying;
        emit(playing.copyWith(volume: event.volume));
      } else if (state is PlayerPaused) {
        final paused = state as PlayerPaused;
        emit(paused.copyWith(volume: event.volume));
      }
    } catch (e) {
      emit(PlayerError('Failed to set volume: $e'));
    }
  }

  Future<void> _onSetPlaybackRate(SetPlaybackRateEvent event, Emitter<PlayerState> emit) async {
    try {
      await _audioService.setPlaybackRate(event.rate);
      if (state is PlayerPlaying) {
        final playing = state as PlayerPlaying;
        emit(playing.copyWith(playbackRate: event.rate));
      } else if (state is PlayerPaused) {
        final paused = state as PlayerPaused;
        emit(paused.copyWith(playbackRate: event.rate));
      }
    } catch (e) {
      emit(PlayerError('Failed to set playback rate: $e'));
    }
  }

  Future<void> _onNextSong(NextSongEvent event, Emitter<PlayerState> emit) async {
    if (_queue.isEmpty || _currentSong == null || _isChangingSong) return;

    final sequence = _audioService.player.sequence;
    if (sequence.length > 1 && _audioService.player.hasNext) {
      await _audioService.seekToNext();
      return;
    }

    Song? nextSong;
    if (_isShuffle && _queue.length > 1) {
      final available = _queue.where((s) => s.id != _currentSong!.id).toList();
      if (available.isNotEmpty) {
        available.shuffle();
        nextSong = available.first;
      }
    } else {
      final currentIndex = _queue.indexWhere((s) => s.id == _currentSong!.id);
      if (currentIndex != -1 && currentIndex < _queue.length - 1) {
        nextSong = _queue[currentIndex + 1];
      } else if (_queue.isNotEmpty) {
        nextSong = _queue.first; // Wrap around
      }
    }

    if (nextSong != null) {
      await _playSongInternal(nextSong, emit);
    }
  }

  Future<void> _onPreviousSong(PreviousSongEvent event, Emitter<PlayerState> emit) async {
    if (_queue.isEmpty || _currentSong == null || _isChangingSong) return;

    final sequence = _audioService.player.sequence;
    if (sequence.length > 1 && _audioService.player.hasPrevious) {
      await _audioService.seekToPrevious();
      return;
    }

    Song? prevSong;
    final currentIndex = _queue.indexWhere((s) => s.id == _currentSong!.id);
    if (currentIndex > 0) {
      prevSong = _queue[currentIndex - 1];
    } else if (_queue.isNotEmpty) {
      prevSong = _queue.last; // Wrap around
    }

    if (prevSong != null) {
      await _playSongInternal(prevSong, emit);
    }
  }

  void _onToggleShuffle(ToggleShuffleEvent event, Emitter<PlayerState> emit) {
    _isShuffle = !_isShuffle;
    _settingsService?.setShuffleByDefault(_isShuffle);
    _applyShuffleQueueState();
    _emitUpdatedQueueState(emit);
  }

  void _onSetShuffle(SetShuffleEvent event, Emitter<PlayerState> emit) {
    _isShuffle = event.enabled;
    _settingsService?.setShuffleByDefault(_isShuffle);
    _applyShuffleQueueState();
    _emitUpdatedQueueState(emit);
  }

  void _applyShuffleQueueState() {
    if (_isShuffle && _queue.isNotEmpty) {
      if (_originalQueue.isEmpty) {
        _originalQueue = List.from(_queue);
      }
      _queue.shuffle();
      if (_currentSong != null) {
        _queue.removeWhere((s) => s.id == _currentSong!.id);
        _queue.insert(0, _currentSong!);
      }
    } else if (!_isShuffle && _originalQueue.isNotEmpty) {
      _queue = List.from(_originalQueue);
    }
  }

  void _onToggleRepeat(ToggleRepeatEvent event, Emitter<PlayerState> emit) {
    if (_repeatMode == 'Off') {
      _repeatMode = 'One';
      _isRepeat = true;
    } else if (_repeatMode == 'One') {
      _repeatMode = 'All';
      _isRepeat = true;
    } else {
      _repeatMode = 'Off';
      _isRepeat = false;
    }
    if (state is PlayerPlaying) {
      emit((state as PlayerPlaying).copyWith(isRepeat: _isRepeat, repeatMode: _repeatMode));
    } else if (state is PlayerPaused) {
      emit((state as PlayerPaused).copyWith(isRepeat: _isRepeat, repeatMode: _repeatMode));
    }
  }

  void _onSetRepeatMode(SetRepeatModeEvent event, Emitter<PlayerState> emit) {
    _repeatMode = event.mode;
    _isRepeat = event.mode != 'Off';
    if (state is PlayerPlaying) {
      emit((state as PlayerPlaying).copyWith(isRepeat: _isRepeat, repeatMode: _repeatMode));
    } else if (state is PlayerPaused) {
      emit((state as PlayerPaused).copyWith(isRepeat: _isRepeat, repeatMode: _repeatMode));
    }
  }

  void _onSetAutoPlayNext(SetAutoPlayNextEvent event, Emitter<PlayerState> emit) {
    _autoPlayNext = event.enabled;
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    _audioService.dispose();
    return super.close();
  }
}
