import 'dart:async';
import 'package:flutter/foundation.dart';
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
    on<RestoreLastPlayedEvent>(_onRestoreLastPlayed);
    on<PositionChangedEvent>(_onPositionChanged);
    on<DurationChangedEvent>(_onDurationChanged);

    _listenToStreams();
    add(const RestoreLastPlayedEvent());
  }

  void _listenToStreams() {
    _positionSubscription = _audioService.positionStream.listen((pos) {
      add(PositionChangedEvent(pos));
    });

    _durationSubscription = _audioService.durationStream.listen((dur) {
      if (dur != null) {
        add(DurationChangedEvent(dur));
      }
    });

    _currentIndexSubscription = _audioService.player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && !_isChangingSong) {
        final sequence = _audioService.player.sequenceState.sequence;
        if (index < sequence.length) {
          final tag = sequence[index].tag;
          if (tag is MediaItem) {
            final songId = int.tryParse(tag.id);
            if (songId != null) {
              final matching = _queue.where((s) => s.id == songId);
              if (matching.isNotEmpty) {
                _currentSong = matching.first;
                return;
              }
            }
          }
          if (sequence.length == _queue.length && index < _queue.length) {
            _currentSong = _queue[index];
          }
        }
      }
    });

    _playerStateSubscription = _audioService.playerStateStream.listen((playerState) async {
      final procState = playerState.processingState;
      final isPlaying = playerState.playing;

      if (procState == ProcessingState.ready && isPlaying) {
        _isChangingSong = false;
      }

      if (_isChangingSong) return;

      if (procState == ProcessingState.completed) {
        _isChangingSong = true;
        if ((_repeatMode == 'One' || _isRepeat) && _currentSong != null) {
          add(PlaySongEvent(_currentSong!));
        } else if (_autoPlayNext) {
          add(const NextSongEvent());
        } else {
          await _audioService.pause();
          await _audioService.seek(Duration.zero);
          add(const PauseEvent());
          _isChangingSong = false;
        }
        return;
      }

      if (procState == ProcessingState.ready || procState == ProcessingState.buffering) {
        if (!isPlaying && state is PlayerPlaying) {
          add(const PauseEvent());
        } else if (isPlaying && state is PlayerPaused) {
          add(const ResumeEvent());
        }
      }
    });
  }

  void _onPositionChanged(PositionChangedEvent event, Emitter<PlayerState> emit) {
    if (_currentSong != null) {
      _settingsService?.setLastPlayedSongId(_currentSong!.id);
      _settingsService?.setLastPlayedPositionMs(event.position.inMilliseconds);
    }
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

    final previousSong = _currentSong;

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
        _repository?.updateSong(activeSong, notify: false);
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
      _currentSong = previousSong;
      debugPrint('Failed to play song (${song.filePath}): $e');
      emit(PlayerError('Failed to play song: $e'));
    }
  }

  Future<void> _onPlaySong(PlaySongEvent event, Emitter<PlayerState> emit) async {
    if (event.queue != null && event.queue!.isNotEmpty) {
      _queue = List.from(event.queue!);
      _originalQueue = List.from(event.queue!);
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
    await _playSongInternal(_currentSong!, emit);
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
      final song = _currentSong ?? (state is PlayerPlaying ? (state as PlayerPlaying).song : null);
      if (song != null) {
        final pos = _audioService.player.position;
        final dur = _audioService.player.duration ?? song.duration;
        emit(PlayerPaused(
          song: song,
          position: pos,
          duration: dur,
          isShuffle: _isShuffle,
          isRepeat: _isRepeat,
          repeatMode: _repeatMode,
          queue: List.from(_queue),
        ));
      }
    } catch (e) {
      emit(PlayerError('Failed to pause: $e'));
    }
  }

  Future<void> _onResume(ResumeEvent event, Emitter<PlayerState> emit) async {
    try {
      await _audioService.resume();
      final song = _currentSong ?? (state is PlayerPaused ? (state as PlayerPaused).song : null);
      if (song != null) {
        final pos = _audioService.player.position;
        final dur = _audioService.player.duration ?? song.duration;
        emit(PlayerPlaying(
          song: song,
          position: pos,
          duration: dur,
          isShuffle: _isShuffle,
          isRepeat: _isRepeat,
          repeatMode: _repeatMode,
          queue: List.from(_queue),
        ));
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
      _settingsService?.setLastPlayedPositionMs(event.position.inMilliseconds);
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

  Future<void> _onRestoreLastPlayed(
      RestoreLastPlayedEvent event, Emitter<PlayerState> emit) async {
    if (_settingsService?.resumeLastSong != true) return;
    final lastId = _settingsService?.lastPlayedSongId;
    if (lastId == null || _repository == null) return;

    try {
      final allSongs = await _repository.getAllSongs();
      final songMatches = allSongs.where((s) => s.id == lastId);
      if (songMatches.isEmpty) return;
      final song = songMatches.first;

      final posMs = _settingsService?.lastPlayedPositionMs ?? 0;
      final pos = Duration(milliseconds: posMs);

      _currentSong = song;
      _queue = [song];
      _originalQueue = [song];

      await _audioService.prepare(song);
      if (pos > Duration.zero) {
        await _audioService.seek(pos);
      }

      emit(PlayerPaused(
        song: song,
        position: pos,
        duration: song.duration,
        isShuffle: _isShuffle,
        isRepeat: _isRepeat,
        queue: _queue,
      ));
    } catch (_) {}
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
    _autoPlayNext = event.autoPlayNext;
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
