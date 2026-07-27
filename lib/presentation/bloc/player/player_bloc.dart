import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart' hide PlayerEvent, PlayerState;
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/services/audio_service.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final AudioPlayerService _audioService;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;

  Song? _currentSong;
  List<Song> _queue = [];
  bool _isShuffle = false;
  bool _isRepeat = false;

  PlayerBloc({required AudioPlayerService audioService})
      : _audioService = audioService,
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
      if (playerState.processingState == ProcessingState.completed) {
        if (_isRepeat && _currentSong != null) {
          add(PlaySongEvent(_currentSong!, queue: _queue));
        } else {
          add(const NextSongEvent());
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

  Future<void> _onPlaySong(PlaySongEvent event, Emitter<PlayerState> emit) async {
    try {
      _currentSong = event.song;
      if (event.queue != null && event.queue!.isNotEmpty) {
        _queue = List.from(event.queue!);
      }
      emit(PlayerLoading(song: event.song));
      await _audioService.play(event.song.filePath);

      final dur = _audioService.player.duration ?? event.song.duration;
      emit(PlayerPlaying(
        song: event.song,
        position: Duration.zero,
        duration: dur,
        isShuffle: _isShuffle,
        isRepeat: _isRepeat,
        queue: _queue,
      ));
    } catch (e) {
      emit(PlayerError('Failed to play song: $e'));
    }
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
        add(PlaySongEvent(_currentSong!));
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
    if (_queue.isEmpty || _currentSong == null) return;
    final currentIndex = _queue.indexWhere((s) => s.id == _currentSong!.id);
    if (currentIndex != -1 && currentIndex < _queue.length - 1) {
      add(PlaySongEvent(_queue[currentIndex + 1], queue: _queue));
    } else if (_queue.isNotEmpty) {
      add(PlaySongEvent(_queue.first, queue: _queue));
    }
  }

  Future<void> _onPreviousSong(PreviousSongEvent event, Emitter<PlayerState> emit) async {
    if (_queue.isEmpty || _currentSong == null) return;
    final currentIndex = _queue.indexWhere((s) => s.id == _currentSong!.id);
    if (currentIndex > 0) {
      add(PlaySongEvent(_queue[currentIndex - 1], queue: _queue));
    } else if (_queue.isNotEmpty) {
      add(PlaySongEvent(_queue.last, queue: _queue));
    }
  }

  void _onToggleShuffle(ToggleShuffleEvent event, Emitter<PlayerState> emit) {
    _isShuffle = !_isShuffle;
    if (_isShuffle && _queue.isNotEmpty) {
      _queue.shuffle();
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
