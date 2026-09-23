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

class PlayQueueEvent extends PlayerEvent {
  final List<Song> queue;
  final int initialIndex;

  const PlayQueueEvent(this.queue, {this.initialIndex = 0});

  @override
  List<Object?> get props => [queue, initialIndex];
}

class PlaySongAtIndexEvent extends PlayerEvent {
  final int index;
  const PlaySongAtIndexEvent(this.index);

  @override
  List<Object?> get props => [index];
}

class InsertNextEvent extends PlayerEvent {
  final Song song;
  const InsertNextEvent(this.song);

  @override
  List<Object?> get props => [song];
}

class AddToQueueEvent extends PlayerEvent {
  final Song song;
  const AddToQueueEvent(this.song);

  @override
  List<Object?> get props => [song];
}

class RemoveFromQueueEvent extends PlayerEvent {
  final int index;
  const RemoveFromQueueEvent(this.index);

  @override
  List<Object?> get props => [index];
}

class ReorderQueueEvent extends PlayerEvent {
  final int oldIndex;
  final int newIndex;

  const ReorderQueueEvent(this.oldIndex, this.newIndex);

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

class ClearQueueEvent extends PlayerEvent {
  const ClearQueueEvent();
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

class SetShuffleEvent extends PlayerEvent {
  final bool enabled;
  const SetShuffleEvent(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ToggleRepeatEvent extends PlayerEvent {
  const ToggleRepeatEvent();
}

class SetRepeatModeEvent extends PlayerEvent {
  final String mode;
  const SetRepeatModeEvent(this.mode);

  @override
  List<Object?> get props => [mode];
}

class SetAutoPlayNextEvent extends PlayerEvent {
  final bool autoPlayNext;
  const SetAutoPlayNextEvent(this.autoPlayNext);

  @override
  List<Object?> get props => [autoPlayNext];
}

class RestoreLastPlayedEvent extends PlayerEvent {
  const RestoreLastPlayedEvent();
}

class PositionChangedEvent extends PlayerEvent {
  final Duration position;
  const PositionChangedEvent(this.position);

  @override
  List<Object?> get props => [position];
}

class DurationChangedEvent extends PlayerEvent {
  final Duration duration;
  const DurationChangedEvent(this.duration);

  @override
  List<Object?> get props => [duration];
}

class TrackChangedEvent extends PlayerEvent {
  final Song song;
  final int sequenceIndex;
  final int sequenceLength;

  const TrackChangedEvent(
    this.song, {
    this.sequenceIndex = 0,
    this.sequenceLength = 0,
  });

  @override
  List<Object?> get props => [song, sequenceIndex, sequenceLength];
}

