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
import 'package:vinyl/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:vinyl/presentation/widgets/album_art_widget.dart';
import 'package:vinyl/presentation/widgets/download_queue_snackbar.dart';
import 'package:vinyl/services/download_service.dart';
import 'package:vinyl/services/stream_favorites_service.dart';

/// Modal bottom sheet presenting all actions for a song:
/// 1. Start Radio
/// 2. Add to Queue
/// 3. Add to Playlist
/// 4. Favorite (Add/Remove)
/// 5. Download
class SongOptionsBottomSheet extends StatelessWidget {
  final Song song;
  final VoidCallback? onDownload;

  const SongOptionsBottomSheet({
    super.key,
    required this.song,
    this.onDownload,
  });

  static Future<void> show(
    BuildContext context, {
    required Song song,
    VoidCallback? onDownload,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SongOptionsBottomSheet(
        song: song,
        onDownload: onDownload,
      ),
    );
  }

  bool _isStreamSong(Song s) {
    return s.filePath.startsWith('http://') ||
        s.filePath.startsWith('https://') ||
        s.source == 'jiosaavn';
  }

  bool _checkIsFavorite(BuildContext context, bool isStream) {
    if (isStream) {
      return StreamFavoritesService.instance.isFavorite(song.id);
    }
    final libState = context.read<LibraryBloc>().state;
    if (libState is LibraryLoaded) {
      final favIndex = libState.playlists
          .indexWhere((p) => p.name.toLowerCase() == 'favorites');
      if (favIndex != -1) {
        return libState.playlists[favIndex].songs.any((s) => s.id == song.id);
      }
    }
    return false;
  }

  void _handleStartRadio(BuildContext context) {
    Navigator.pop(context);
    context.read<PlayerBloc>().add(StartRadioEvent(song));
  }

  void _handleAddToQueue(BuildContext context) {
    Navigator.pop(context);
    context.read<PlayerBloc>().add(AddToQueueEvent(song));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added "${song.title}" to queue',
          style: GoogleFonts.outfit(),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleAddToPlaylist(BuildContext context) {
    Navigator.pop(context);
    AddToPlaylistSheet.show(context, song, isStream: _isStreamSong(song));
  }

  Future<void> _handleToggleFavorite(
      BuildContext context, bool isStream, bool isFav) async {
    Navigator.pop(context);
    if (isStream) {
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
    } else {
      context.read<LibraryBloc>().add(ToggleFavoriteEvent(song));
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
  }

  void _handleDownload(BuildContext context, bool isStream) {
    Navigator.pop(context);
    if (onDownload != null) {
      onDownload!();
      return;
    }

    if (isStream && (song.filePath.startsWith('http') || File(song.filePath).existsSync())) {
      final downloadService = getIt<DownloadService>();
      downloadService.enqueueDownload(
        url: song.filePath,
        title: song.title,
        artist: song.artist,
        album: song.album,
        albumArt: song.albumArt,
        duration: song.duration,
      );
      showDownloadQueuedSnackBar(context, title: song.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isStream = _isStreamSong(song);
    final isFav = _checkIsFavorite(context, isStream);
    final canDownload = onDownload != null || (isStream && (song.filePath.startsWith('http') || File(song.filePath).existsSync()));

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
              // Top Drag Handle
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

              // Header with song info
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
                          Text(
                            song.artist.isNotEmpty ? song.artist : 'Unknown Artist',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
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
                subtitle: 'Save track to your custom playlists',
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
                onTap: () => _handleToggleFavorite(context, isStream, isFav),
              ),

              // 5. Download (shown if stream song or download callback available)
              if (canDownload)
                _buildOptionTile(
                  context: context,
                  icon: Icons.download_rounded,
                  title: 'Download Song',
                  subtitle: 'Save to device for offline listening',
                  onTap: () => _handleDownload(context, isStream),
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
        child: Icon(
          icon,
          color: iconColor ?? primaryColor,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
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
