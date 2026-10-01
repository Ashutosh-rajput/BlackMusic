import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl/core/utils/song_origin.dart';
import 'package:vinyl/data/models/song_model.dart';

void main() {
  Song song({required String path, String? source, String? genre, String album = 'Album'}) => Song(
        id: 1,
        title: 'Track',
        artist: 'Artist',
        album: album,
        filePath: path,
        duration: const Duration(minutes: 3),
        dateModified: DateTime(2026, 1, 1),
        source: source,
        genre: genre,
      );

  group('SongOrigin', () {
    test('stream paths: web URL, unresolved, offline stream cache', () {
      expect(SongOrigin.isStreamPath('https://aac.saavncdn.com/x_320.mp4'), isTrue);
      expect(SongOrigin.isStreamPath(''), isTrue);
      expect(SongOrigin.isStreamPath('/data/user/0/com.muskmelon.vinyl/cache/stream_cache/1.m4a'), isTrue);
      expect(SongOrigin.isStreamPath('/storage/emulated/0/Music/song.mp3'), isFalse);
      expect(SongOrigin.isStreamPath('/storage/emulated/0/Download/vinyl/Song.m4a'), isFalse);
    });

    test('Stream songs, including ones cached for offline playback', () {
      expect(SongOrigin.isStream(song(path: 'https://aac.saavncdn.com/x.mp4', source: 'jiosaavn')), isTrue);
      expect(SongOrigin.isStream(song(path: '', source: 'jiosaavn')), isTrue);
      expect(
        SongOrigin.isStream(song(path: '/data/user/0/x/cache/stream_cache/1.m4a', source: 'jiosaavn')),
        isTrue,
      );
    });

    test('Library songs: imported, scanned, YouTube and Stream downloads', () {
      expect(SongOrigin.isLibrary(song(path: '/storage/emulated/0/Music/a.mp3', source: 'local')), isTrue);
      expect(SongOrigin.isLibrary(song(path: '/storage/emulated/0/Music/a.mp3')), isTrue);
      expect(
        SongOrigin.isLibrary(song(path: '/storage/emulated/0/Download/vinyl/a.m4a', source: 'youtube', album: 'YouTube Downloads')),
        isTrue,
      );
      // Downloaded from Stream: a Library song now, even though source is jiosaavn.
      expect(
        SongOrigin.isLibrary(song(path: '/storage/emulated/0/Download/vinyl/a.m4a', source: 'jiosaavn', genre: 'Downloaded')),
        isTrue,
      );
    });
  });
}
