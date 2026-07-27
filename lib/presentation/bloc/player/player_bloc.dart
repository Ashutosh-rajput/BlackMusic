import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart' hide PlayerEvent, PlayerState;
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:pixel_player/services/audio_service.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final AudioPlayerService _audioService;
  final MusicRepository? _repository;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;

  Song? _currentSong;
  List<Song> _queue = [];
  List<Song> _originalQueue = []; // Preserved for restoring order after shuffle
  bool _isShuffle = false;
  bool _isRepeat = false;
  bool _isChangingSong = false;

  PlayerBloc({
    required AudioPlayerService audioService,
    MusicRepository? repository,
  })  : _audioService = audioService,
        _repository = repository,
        super(const PlayerInitial()) {
    on<PlaySongEvent>(_onPlaySong);
    on<PauseEvent>(_onPause);
    on<ResumeEvent>(_onResume);
    on<StopEvent>(_onStop);
    on<SeekEvent>(_onSeek);
    on<SetVolumeEvent>(_onSetVolume);
    on<SetPlaybackRateEvent>(_onSetPlaybackRate);
    on<NextSongEvent>(_onNextSong);
    on<PreviousSongEvent>(_onPreviousSong);
    on<ToggleShuffleEvent>(_onToggleShuffle);
    on<ToggleRepeatEvent>(_onToggleRepeat);
    on<PositionChangedEvent>(_onPositionChanged);
    on<DurationChangedEvent>(_onDurationChanged);

    _listenToStreams();
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

    _playerStateSubscription = _audioService.playerStateStream.listen((playerState) {
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
          if (_isRepeat && _currentSong != null) {
            add(PlaySongEvent(_currentSong!));
          } else {
            add(const NextSongEvent());
          }
        }
      }
    });
  }

  void _onPositionChanged(PositionChangedEvent event, Emitter<PlayerState> emit) {
    if (state is PlayerPlaying) {
      final current = state as PlayerPlaying;
      emit(current.copyWith(position: event.position));
    } else if (state is PlayerPaused) {
      final current = state as PlayerPaused;
      emit(current.copyWith(position: event.position));
    }
  }

  void _onDurationChanged(DurationChangedEvent event, Emitter<PlayerState> emit) {
    if (state is PlayerPlaying) {
      final current = state as PlayerPlaying;
      emit(current.copyWith(duration: event.duration));
    } else if (state is PlayerPaused) {
      final current = state as PlayerPaused;
      emit(current.copyWith(duration: event.duration));
    }
  }

  /// Shared internal play method — called by _onPlaySong, _onNextSong, _onPreviousSong.
  /// Sets _isChangingSong atomically to prevent the stream listener from firing
  /// a duplicate advance during song transitions.
  Future<void> _playSongInternal(Song song, Emitter<PlayerState> emit) async {
    // Allow replaying the same song if it has completed (for repeat mode)
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
      await _audioService.play(song.filePath);

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
    } catch (e) {
      _isChangingSong = false;
      if (e.toString().contains('Loading interrupted')) {
        return; // Silently handle interruption from rapid skipping
      }
      emit(PlayerError('Failed to play song: $e'));
    }
  }

  Future<void> _onPlaySong(PlaySongEvent event, Emitter<PlayerState> emit) async {
    if (event.queue != null && event.queue!.isNotEmpty) {
      _queue = List.from(event.queue!);
      _originalQueue = List.from(event.queue!);
    }
    await _playSongInternal(event.song, emit);
  }

  Future<void> _onPause(PauseEvent event, Emitter<PlayerState> emit) async {
    try {
      await _audioService.pause();
      if (state is PlayerPlaying) {
        final playing = state as PlayerPlaying;
        emit(PlayerPaused(
          song: playing.song,
          position: playing.position,
          duration: playing.duration,
          volume: playing.volume,
          playbackRate: playing.playbackRate,
          isShuffle: playing.isShuffle,
          isRepeat: playing.isRepeat,
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

  /// Directly plays the next song — no intermediate event dispatch, so no race condition gap.
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

  /// Directly plays the previous song — no intermediate event dispatch.
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
    if (_isShuffle && _queue.isNotEmpty) {
      // Save original order before shuffling
      _originalQueue = List.from(_queue);
      _queue.shuffle();
    } else if (!_isShuffle && _originalQueue.isNotEmpty) {
      // Restore original order when shuffle is turned off
      _queue = List.from(_originalQueue);
    }
    if (state is PlayerPlaying) {
      emit((state as PlayerPlaying).copyWith(isShuffle: _isShuffle, queue: _queue));
    } else if (state is PlayerPaused) {
      emit((state as PlayerPaused).copyWith(isShuffle: _isShuffle, queue: _queue));
    }
  }

  void _onToggleRepeat(ToggleRepeatEvent event, Emitter<PlayerState> emit) {
    _isRepeat = !_isRepeat;
    if (state is PlayerPlaying) {
      emit((state as PlayerPlaying).copyWith(isRepeat: _isRepeat));
    } else if (state is PlayerPaused) {
      emit((state as PlayerPaused).copyWith(isRepeat: _isRepeat));
    }
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioService.dispose();
    return super.close();
  }
}
