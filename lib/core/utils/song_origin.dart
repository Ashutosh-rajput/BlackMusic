import 'package:vinyl/data/models/song_model.dart';

/// The single rule for which side of the app a song belongs to.
///
/// Library and Stream are kept strictly apart (Stream songs need internet,
/// Library songs must keep working offline), so every layer — database
/// queries, playback, Autoplay, downloads, menus — decides through here
/// instead of each keeping its own slightly different check.
///
/// - **Stream**: played from JioSaavn. Its path is a web URL, empty (URL not
///   resolved yet), or a file inside the app's offline stream cache.
/// - **Library**: a real file on the device — imported, scanned, or
///   downloaded (including songs downloaded from Stream).
class SongOrigin {
  SongOrigin._();

  /// Marker of the offline stream cache folder (see StreamCacheService).
  static const String streamCacheDirMarker = '/stream_cache/';

  /// True when [filePath] is a Stream location rather than a Library file.
  static bool isStreamPath(String filePath) {
    final path = filePath.trim().replaceAll(r'\', '/');
    return path.isEmpty ||
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.contains(streamCacheDirMarker);
  }

  /// True for Stream songs (including ones cached for offline playback).
  static bool isStream(Song song) {
    // Downloads are Library songs even when they came from Stream.
    if (song.genre == 'Downloaded' || song.album == 'YouTube Downloads') return false;
    if (song.source == 'local' || song.source == 'youtube') return false;
    if (song.source == 'jiosaavn') return true;
    return isStreamPath(song.filePath);
  }

  /// True for Library songs (files on the device).
  static bool isLibrary(Song song) => !isStream(song);
}
