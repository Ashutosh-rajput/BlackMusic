import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinyl/core/di/injection_container.dart';
import 'package:vinyl/data/models/song_model.dart';
import 'package:vinyl/presentation/bloc/library/library_bloc.dart';
import 'package:vinyl/presentation/bloc/library/library_event.dart';
import 'package:vinyl/presentation/bloc/library/library_state.dart';
import 'package:vinyl/presentation/bloc/player/player_bloc.dart';
import 'package:vinyl/presentation/bloc/player/player_event.dart';
import 'package:vinyl/presentation/bloc/player/player_state.dart';
import 'package:vinyl/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:vinyl/presentation/widgets/album_art_widget.dart';
import 'package:vinyl/presentation/widgets/download_queue_snackbar.dart';
import 'package:vinyl/services/download_service.dart';
import 'package:vinyl/services/media_delete_service.dart';
import 'package:vinyl/services/stream_cache_service.dart';
import 'package:vinyl/services/stream_favorites_service.dart';

/// Modal bottom sheet presenting all actions for a song.
///
/// Song classification (drives which actions are shown):
///   - [_isLocalLibrarySong]  → saved in local DB (youtube/local/downloaded)
///   - [_isStreamCached]      → a JioSaavn stream song cached to disk (but NOT in local library)
///   - [_isLiveStream]        → pure live stream URL with no local file
///
/// Rules:
///   - Local library song  → show "Delete from Library" (removes file + DB row)
///   - Offline-cached only → show "Remove from Cache" (only clears the stream cache)
///   - Live stream         → no delete / cache-remove (nothing to delete locally)
class SongOptionsBottomSheet extends StatelessWidget {
  final Song song;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  /// Only true when opened from the Offline Cache section; gates the
  /// "Remove from Cache" tile.
  final bool showRemoveFromCache;

  /// Only true when opened from the Library; gates "Delete from Library"
  /// (removes the DB row and the file from the phone).
  final bool showDeleteFromLibrary;
  final VoidCallback? onCacheRemoved;

  const SongOptionsBottomSheet({
    super.key,
    required this.song,
    this.onDownload,
    this.onDelete,
    this.showRemoveFromCache = false,
    this.showDeleteFromLibrary = false,
    this.onCacheRemoved,
  });

  static Future<void> show(
    BuildContext context, {
    required Song song,
    VoidCallback? onDownload,
    VoidCallback? onDelete,
    bool showRemoveFromCache = false,
    bool showDeleteFromLibrary = false,
    VoidCallback? onCacheRemoved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SongOptionsBottomSheet(
        song: song,
        onDownload: onDownload,
        onDelete: onDelete,
        showRemoveFromCache: showRemoveFromCache,
        showDeleteFromLibrary: showDeleteFromLibrary,
        onCacheRemoved: onCacheRemoved,
      ),
    );
  }

  // ─── Song classification helpers ──────────────────────────────────────────

  /// True when the song lives in the local library (downloaded from YouTube,
  /// imported local file, or any non-stream source with an on-disk file).
  bool _isLocalLibrarySong() {
    // Explicit source flags take priority
    if (song.source == 'local' || song.source == 'youtube') return true;
    if (song.genre == 'Downloaded' || song.album == 'YouTube Downloads') return true;
    // Stream songs (even when cached to disk) are never library songs
    if (song.source == 'jiosaavn') return false;
    // A stream URL can never be local
    final fp = song.filePath.trim();
    if (fp.isEmpty) return false;
    if (fp.startsWith('http://') || fp.startsWith('https://')) return false;
    // Only check the filesystem as a last resort (may not be available in tests)
    try {
      return File(fp).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// True when the song is a JioSaavn stream song that has been cached to disk
  /// by [StreamCacheService] but is NOT a permanent library download.
  bool _isStreamCached() => StreamCacheService.instance.isSongCached(song.id);

  /// True when the song is a pure live network stream with no local copy at all.
  bool _isLiveStream() {
    final fp = song.filePath.trim();
    if (fp.startsWith('http://') || fp.startsWith('https://')) return true;
    if (fp.isEmpty && song.source == 'jiosaavn') return true;
    return false;
  }

  // ─── Favorite helper ──────────────────────────────────────────────────────

  bool _checkIsFavorite(BuildContext context) {
    if (_isLocalLibrarySong()) {
      final libState = context.read<LibraryBloc>().state;
      if (libState is LibraryLoaded) {
        final favIndex =
            libState.playlists.indexWhere((p) => p.name.toLowerCase() == 'favorites');
        if (favIndex != -1) {
          return libState.playlists[favIndex].songs.any((s) => s.id == song.id);
        }
      }
      return false;
    }
    return StreamFavoritesService.instance.isFavorite(song.id);
  }

  // ─── Action handlers ──────────────────────────────────────────────────────

  void _handleStartRadio(BuildContext context) {
    Navigator.pop(context);
    context.read<PlayerBloc>().add(StartRadioEvent(song));
  }

  void _handleAddToQueue(BuildContext context) {
    Navigator.pop(context);
    context.read<PlayerBloc>().add(AddToQueueEvent(song));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${song.title}" to queue', style: GoogleFonts.outfit()),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleAddToPlaylist(BuildContext context) {
    Navigator.pop(context);
    // Pass isStream=true for any non-library song so it goes to stream playlists
    AddToPlaylistSheet.show(context, song, isStream: !_isLocalLibrarySong());
  }

  Future<void> _handleToggleFavorite(BuildContext context, bool isFav) async {
    Navigator.pop(context);
    if (_isLocalLibrarySong()) {
      context.read<LibraryBloc>().add(ToggleFavoriteEvent(song));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFav
                  ? 'Removed "${song.title}" from Favorites'
                  : 'Added "${song.title}" to Favorites',
              style: GoogleFonts.outfit(),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final added = await StreamFavoritesService.instance.toggleFavorite(song);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added
                  ? 'Added "${song.title}" to Stream Favorites'
                  : 'Removed from Stream Favorites',
              style: GoogleFonts.outfit(),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleDownload(BuildContext context) {
    Navigator.pop(context);
    if (onDownload != null) {
      onDownload!();
      return;
    }
    final fp = song.filePath.trim();
    if (fp.startsWith('http') || File(fp).existsSync()) {
      final downloadService = getIt<DownloadService>();
      downloadService.enqueueDownload(
        url: fp,
        title: song.title,
        artist: song.artist,
        album: song.album,
        albumArt: song.albumArt,
        duration: song.duration,
      );
      showDownloadQueuedSnackBar(context, title: song.title);
    }
  }

  /// Removes [song] from the play queue. If it is the song playing now, the
  /// queue removal itself moves playback on, so no separate "next" is sent
  /// (sending both could skip two songs).
  void _removeFromPlayer(PlayerBloc playerBloc) {
    final playerState = playerBloc.state;
    final queue = playerState is PlayerPlaying
        ? playerState.queue
        : (playerState is PlayerPaused ? playerState.queue : null);
    if (queue == null) return;
    final qIndex = queue.indexWhere((s) => s.id == song.id);
    if (qIndex != -1) playerBloc.add(RemoveFromQueueEvent(qIndex));
  }

  SnackBar _snackBar(String text) => SnackBar(
        content: Text(text, style: GoogleFonts.outfit()),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      );

  /// Delete from local library (removes DB record and the physical audio file).
  Future<void> _handleDeleteFromLibrary(BuildContext context) async {
    // Confirm while the sheet is still open: once the sheet is popped its
    // context is unmounted and nothing after the dialog could run.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Song', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${song.title}"? This will permanently remove the track from your library and delete the audio file from your device.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final playerBloc = context.read<PlayerBloc>();
    final libraryBloc = context.read<LibraryBloc>();
    Navigator.pop(context);

    if (onDelete != null) {
      onDelete!();
      return;
    }

    try {
      // Delete the audio file first. For music another app put on the phone,
      // Android shows its own "Allow Vinyl to delete…" prompt here. Only touch
      // the library and the queue once the file is really gone.
      final path = song.filePath.trim();
      if (path.isNotEmpty && !path.startsWith('http')) {
        final result = await MediaDeleteService.deleteAudioFile(path);
        if (result == MediaDeleteResult.cancelled) {
          messenger.showSnackBar(_snackBar('Delete cancelled. "${song.title}" was kept.'));
          return;
        }
        if (result == MediaDeleteResult.failed) {
          messenger.showSnackBar(_snackBar(
              'Android did not allow deleting "${song.title}". It was kept in your library.'));
          return;
        }
      }

      _removeFromPlayer(playerBloc);
      // The audio file is already gone; this removes the library entry and
      // the downloaded artwork.
      libraryBloc.add(DeleteSongEvent(song, deleteFile: true));
      if (StreamCacheService.instance.isSongCached(song.id)) {
        await StreamCacheService.instance.removeCachedSong(song.id);
      }
      messenger.showSnackBar(_snackBar('Deleted "${song.title}" from library'));
    } catch (e) {
      messenger.showSnackBar(_snackBar('Failed to delete: $e'));
    }
  }

  /// Remove from offline stream cache only (does NOT touch the local library).
  /// Runs instantly, with no confirmation dialog.
  Future<void> _handleRemoveFromCache(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final playerBloc = context.read<PlayerBloc>();
    Navigator.pop(context);

    try {
      _removeFromPlayer(playerBloc);
      await StreamCacheService.instance.removeCachedSong(song.id);
      onCacheRemoved?.call();
      messenger.showSnackBar(_snackBar('Removed "${song.title}" from offline cache'));
    } catch (e) {
      messenger.showSnackBar(_snackBar('Failed to remove from cache: $e'));
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isLocal = _isLocalLibrarySong();
    final isCachedStream = !isLocal && _isStreamCached();
    final isLive = !isLocal && !isCachedStream && _isLiveStream();

    final isFav = _checkIsFavorite(context);

    // Download button: only show for stream/cached songs that aren't already
    // in the local library (downloading from a local library song makes no sense).
    final canDownload = !isLocal &&
        (onDownload != null ||
            song.filePath.startsWith('http') ||
            isCachedStream);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AlbumArtWidget(
                        albumArt: song.albumArt,
                        width: 52,
                        height: 52,
                        fallbackIcon: Icons.music_note_rounded,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (isLocal)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Library',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                )
                              else if (isCachedStream)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Cached',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                )
                              else if (isLive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Stream',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  song.artist.isNotEmpty ? song.artist : 'Unknown Artist',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
              const SizedBox(height: 6),

              // 1. Start Radio
              _buildOptionTile(
                context: context,
                icon: Icons.radio_rounded,
                title: 'Start Radio',
                subtitle: 'Play continuous similar songs',
                onTap: () => _handleStartRadio(context),
              ),

              // 2. Add to Queue
              _buildOptionTile(
                context: context,
                icon: Icons.queue_music_rounded,
                title: 'Add to Queue',
                subtitle: 'Queue this track up next',
                onTap: () => _handleAddToQueue(context),
              ),

              // 3. Add to Playlist
              _buildOptionTile(
                context: context,
                icon: Icons.playlist_add_rounded,
                title: 'Add to Playlist',
                subtitle: isLocal
                    ? 'Save to your library playlists'
                    : 'Save to your stream playlists',
                onTap: () => _handleAddToPlaylist(context),
              ),

              // 4. Favorite Toggle
              _buildOptionTile(
                context: context,
                icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: isFav ? Colors.redAccent : null,
                title: isFav ? 'Remove from Favorites' : 'Add to Favorites',
                subtitle: isFav
                    ? 'Remove this song from favorites'
                    : 'Save this song to favorites',
                onTap: () => _handleToggleFavorite(context, isFav),
              ),

              // 5. Download (stream/cached songs only, not local library)
              if (canDownload)
                _buildOptionTile(
                  context: context,
                  icon: Icons.download_rounded,
                  title: 'Download Song',
                  subtitle: 'Save permanently to device',
                  onTap: () => _handleDownload(context),
                ),

              // 6a. Delete from Library (local library songs only)
              if (showDeleteFromLibrary && isLocal)
                _buildOptionTile(
                  context: context,
                  icon: Icons.delete_outline_rounded,
                  iconColor: Colors.redAccent,
                  title: 'Delete from Library',
                  subtitle: 'Remove from library and device storage',
                  onTap: () => _handleDeleteFromLibrary(context),
                ),

              // 6b. Remove from Cache (stream-cached songs only, NOT library songs)
              if (showRemoveFromCache && isCachedStream)
                _buildOptionTile(
                  context: context,
                  icon: Icons.remove_circle_outline_rounded,
                  iconColor: Colors.orange,
                  title: 'Remove from Cache',
                  subtitle: 'Free up offline cache space',
                  onTap: () => _handleRemoveFromCache(context),
                ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? primaryColor).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? primaryColor, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
