import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/models/playlist_model.dart';
import 'package:pixel_player/services/download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActiveDownload & PlaylistModel Unit Tests', () {
    test('ActiveDownload model correctly tracks progress and status', () {
      final download = ActiveDownload(
        id: 'youtube:video123',
        url: 'https://youtube.com/watch?v=video123',
        title: 'Test Song',
        progress: 0.5,
        statusMessage: 'Downloading 50%',
        status: DownloadStatus.downloading,
        targetPlaylistId: 42,
      );

      expect(download.isDownloading, isTrue);
      expect(download.isCompleted, isFalse);
      expect(download.targetPlaylistId, equals(42));

      final completed = download.copyWith(
        progress: 1.0,
        status: DownloadStatus.completed,
        statusMessage: 'Download complete!',
      );

      expect(completed.isCompleted, isTrue);
      expect(completed.progress, equals(1.0));
      expect(completed.targetPlaylistId, equals(42));
    });

    test('PlaylistModel value equality and copyWith work as expected', () {
      final now = DateTime.now();
      final song = Song(
        id: 1,
        title: 'Track 1',
        artist: 'Artist',
        album: 'Album',
        filePath: '/music/song.mp3',
        duration: const Duration(seconds: 120),
        dateModified: now,
      );

      final playlist = PlaylistModel(
        id: 10,
        name: 'Gym Hits',
        description: 'Auto-created playlist',
        songs: [song],
        dateCreated: now,
        dateModified: now,
      );

      expect(playlist.id, equals(10));
      expect(playlist.name, equals('Gym Hits'));
      expect(playlist.songs.length, equals(1));

      final updated = playlist.copyWith(name: 'Workout Hits');
      expect(updated.name, equals('Workout Hits'));
      expect(updated.id, equals(10));
    });
  });
}
