import 'package:equatable/equatable.dart';
import 'package:pixel_player/data/models/song_model.dart';

abstract class LibraryEvent extends Equatable {
  const LibraryEvent();

  @override
  List<Object?> get props => [];
}

class LoadLibraryEvent extends LibraryEvent {
  const LoadLibraryEvent();
}

class ScanStorageEvent extends LibraryEvent {
  final List<String>? customPaths;
  final bool? ignoreShortAudio;
  final bool? showHiddenFiles;

  const ScanStorageEvent({
    this.customPaths,
    this.ignoreShortAudio,
    this.showHiddenFiles,
  });

  @override
  List<Object?> get props => [customPaths, ignoreShortAudio, showHiddenFiles];
}

class SearchSongsEvent extends LibraryEvent {
  final String query;
  const SearchSongsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class SelectCategoryEvent extends LibraryEvent {
  final String category; // 'All', 'Folders', 'Albums', 'Artists', 'Playlists'
  const SelectCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}

class CreatePlaylistEvent extends LibraryEvent {
  final String name;
  final String? description;
  const CreatePlaylistEvent(this.name, {this.description});

  @override
  List<Object?> get props => [name, description];
}

class DeletePlaylistEvent extends LibraryEvent {
  final int playlistId;
  const DeletePlaylistEvent(this.playlistId);

  @override
  List<Object?> get props => [playlistId];
}

class AddSongToPlaylistEvent extends LibraryEvent {
  final int playlistId;
  final Song song;
  const AddSongToPlaylistEvent(this.playlistId, this.song);

  @override
  List<Object?> get props => [playlistId, song];
}

class RemoveSongFromPlaylistEvent extends LibraryEvent {
  final int playlistId;
  final int songId;
  const RemoveSongFromPlaylistEvent(this.playlistId, this.songId);

  @override
  List<Object?> get props => [playlistId, songId];
}

class ToggleFavoriteEvent extends LibraryEvent {
  final Song song;
  const ToggleFavoriteEvent(this.song);

  @override
  List<Object?> get props => [song];
}
