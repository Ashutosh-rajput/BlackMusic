import 'package:equatable/equatable.dart';

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
  const ScanStorageEvent({this.customPaths});

  @override
  List<Object?> get props => [customPaths];
}

class SearchSongsEvent extends LibraryEvent {
  final String query;
  const SearchSongsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class SelectCategoryEvent extends LibraryEvent {
  final String category; // 'All', 'Albums', 'Artists', 'Playlists'
  const SelectCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}
