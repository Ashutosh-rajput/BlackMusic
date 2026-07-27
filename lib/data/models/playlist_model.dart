import 'package:equatable/equatable.dart';
import 'package:pixel_player/data/models/song_model.dart';

class PlaylistModel extends Equatable {
  final int id;
  final String name;
  final String? description;
  final DateTime dateCreated;
  final DateTime dateModified;
  final List<Song> songs;

  const PlaylistModel({
    required this.id,
    required this.name,
    this.description,
    required this.dateCreated,
    required this.dateModified,
    this.songs = const [],
  });

  PlaylistModel copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? dateCreated,
    DateTime? dateModified,
    List<Song>? songs,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
      songs: songs ?? this.songs,
    );
  }

  @override
  List<Object?> get props => [id, name, description, dateCreated, dateModified, songs];
}
