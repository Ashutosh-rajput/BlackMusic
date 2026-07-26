import 'package:equatable/equatable.dart';
import 'package:pixel_player/data/models/song_model.dart';

abstract class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object?> get props => [];
}

class PlaySongEvent extends PlayerEvent {
  final Song song;
  final List<Song>? queue;

  const PlaySongEvent(this.song, {this.queue});

  @override
  List<Object?> get props => [song, queue];
}

class PauseEvent extends PlayerEvent {
  const PauseEvent();
}

class ResumeEvent extends PlayerEvent {
  const ResumeEvent();
}

class StopEvent extends PlayerEvent {
  const StopEvent();
}

class SeekEvent extends PlayerEvent {
  final Duration position;
  const SeekEvent(this.position);

  @override
  List<Object?> get props => [position];
}

class SetVolumeEvent extends PlayerEvent {
  final double volume;
  const SetVolumeEvent(this.volume);

  @override
  List<Object?> get props => [volume];
}

class SetPlaybackRateEvent extends PlayerEvent {
  final double rate;
  const SetPlaybackRateEvent(this.rate);

  @override
  List<Object?> get props => [rate];
}

class NextSongEvent extends PlayerEvent {
  const NextSongEvent();
}

class PreviousSongEvent extends PlayerEvent {
  const PreviousSongEvent();
}

class ToggleShuffleEvent extends PlayerEvent {
  const ToggleShuffleEvent();
}

class ToggleRepeatEvent extends PlayerEvent {
  const ToggleRepeatEvent();
}
