import 'package:equatable/equatable.dart';
import 'package:pixel_player/data/models/song_model.dart';

abstract class LibraryState extends Equatable {
  const LibraryState();

  @override
  List<Object?> get props => [];
}

class LibraryInitial extends LibraryState {
  const LibraryInitial();
}

class LibraryLoading extends LibraryState {
  const LibraryLoading();
}

class LibraryLoaded extends LibraryState {
  final List<Song> allSongs;
  final List<Song> displayedSongs;
  final String searchQuery;
  final String selectedCategory;

  const LibraryLoaded({
    required this.allSongs,
    required this.displayedSongs,
    this.searchQuery = '',
    this.selectedCategory = 'All',
  });

  LibraryLoaded copyWith({
    List<Song>? allSongs,
    List<Song>? displayedSongs,
    String? searchQuery,
    String? selectedCategory,
  }) {
    return LibraryLoaded(
      allSongs: allSongs ?? this.allSongs,
      displayedSongs: displayedSongs ?? this.displayedSongs,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }

  @override
  List<Object?> get props => [allSongs, displayedSongs, searchQuery, selectedCategory];
}

class LibraryError extends LibraryState {
  final String message;
  const LibraryError(this.message);

  @override
  List<Object?> get props => [message];
}
