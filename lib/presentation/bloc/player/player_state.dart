import 'package:equatable/equatable.dart';
import 'package:pixel_player/data/models/song_model.dart';

abstract class PlayerState extends Equatable {
  const PlayerState();

  @override
  List<Object?> get props => [];
}

class PlayerInitial extends PlayerState {
  const PlayerInitial();
}

class PlayerLoading extends PlayerState {
  final Song? song;
  final bool isShuffle;
  final bool isRepeat;
  final String repeatMode;

  const PlayerLoading({
    this.song,
    this.isShuffle = false,
    this.isRepeat = false,
    this.repeatMode = 'Off',
  });

  @override
  List<Object?> get props => [song, isShuffle, isRepeat, repeatMode];
}

class PlayerPlaying extends PlayerState {
  final Song song;
  final Duration position;
  final Duration duration;
  final double volume;
  final double playbackRate;
  final bool isShuffle;
  final bool isRepeat;
  final String repeatMode;
  final List<Song> queue;

  const PlayerPlaying({
    required this.song,
    required this.position,
    required this.duration,
    this.volume = 1.0,
    this.playbackRate = 1.0,
    this.isShuffle = false,
    this.isRepeat = false,
    this.repeatMode = 'Off',
    this.queue = const [],
  });

  PlayerPlaying copyWith({
    Song? song,
    Duration? position,
    Duration? duration,
    double? volume,
    double? playbackRate,
    bool? isShuffle,
    bool? isRepeat,
    String? repeatMode,
    List<Song>? queue,
  }) {
    return PlayerPlaying(
      song: song ?? this.song,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playbackRate: playbackRate ?? this.playbackRate,
      isShuffle: isShuffle ?? this.isShuffle,
      isRepeat: isRepeat ?? this.isRepeat,
      repeatMode: repeatMode ?? this.repeatMode,
      queue: queue ?? this.queue,
    );
  }

  @override
  List<Object?> get props => [
        song,
        position,
        duration,
        volume,
        playbackRate,
        isShuffle,
        isRepeat,
        repeatMode,
        queue,
      ];
}

class PlayerPaused extends PlayerState {
  final Song song;
  final Duration position;
  final Duration duration;
  final double volume;
  final double playbackRate;
  final bool isShuffle;
  final bool isRepeat;
  final String repeatMode;
  final List<Song> queue;

  const PlayerPaused({
    required this.song,
    required this.position,
    required this.duration,
    this.volume = 1.0,
    this.playbackRate = 1.0,
    this.isShuffle = false,
    this.isRepeat = false,
    this.repeatMode = 'Off',
    this.queue = const [],
  });

  PlayerPaused copyWith({
    Song? song,
    Duration? position,
    Duration? duration,
    double? volume,
    double? playbackRate,
    bool? isShuffle,
    bool? isRepeat,
    String? repeatMode,
    List<Song>? queue,
  }) {
    return PlayerPaused(
      song: song ?? this.song,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playbackRate: playbackRate ?? this.playbackRate,
      isShuffle: isShuffle ?? this.isShuffle,
      isRepeat: isRepeat ?? this.isRepeat,
      repeatMode: repeatMode ?? this.repeatMode,
      queue: queue ?? this.queue,
    );
  }

  @override
  List<Object?> get props => [
        song,
        position,
        duration,
        volume,
        playbackRate,
        isShuffle,
        isRepeat,
        repeatMode,
        queue,
      ];
}

class PlayerStopped extends PlayerState {
  const PlayerStopped();
}

class PlayerError extends PlayerState {
  final String message;
  const PlayerError(this.message);

  @override
  List<Object?> get props => [message];
}
