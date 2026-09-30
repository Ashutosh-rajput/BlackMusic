import 'package:equatable/equatable.dart';
import 'package:vinyl/data/models/song_model.dart';

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'dateCreated': dateCreated.toIso8601String(),
        'dateModified': dateModified.toIso8601String(),
        'songs': songs.map((s) => s.toJson()).toList(),
      };

  factory PlaylistModel.fromJson(Map<String, dynamic> json) => PlaylistModel(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? 'Playlist',
        description: json['description'] as String?,
        dateCreated: DateTime.tryParse(json['dateCreated']?.toString() ?? '') ?? DateTime.now(),
        dateModified: DateTime.tryParse(json['dateModified']?.toString() ?? '') ?? DateTime.now(),
        songs: (json['songs'] as List<dynamic>?)
                ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [id, name, description, dateCreated, dateModified, songs];
}
