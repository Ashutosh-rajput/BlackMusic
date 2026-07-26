import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';
import 'package:pixel_player/presentation/bloc/library/library_state.dart';

void main() {
  test('Song model serialization and value equality test', () {
    final now = DateTime.now();
    final song1 = Song(
      id: 1,
      title: 'Pixel Audio',
      artist: 'Artist',
      album: 'Album',
      filePath: '/path/to/song.mp3',
      duration: const Duration(seconds: 180),
      dateModified: now,
    );

    final json = song1.toJson();
    final song2 = Song.fromJson(json);

    expect(song1, equals(song2));
    expect(song1.title, equals('Pixel Audio'));
  });

  test('Initial BLoC states verification', () {
    const playerInitial = PlayerInitial();
    const libraryInitial = LibraryInitial();

    expect(playerInitial, isA<PlayerState>());
    expect(libraryInitial, isA<LibraryState>());
  });
}
