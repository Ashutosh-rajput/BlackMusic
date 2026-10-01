import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinyl/core/utils/song_origin.dart';
import 'package:vinyl/data/models/playlist_model.dart';
import 'package:vinyl/data/models/song_model.dart';
import 'package:vinyl/presentation/bloc/library/library_bloc.dart';
import 'package:vinyl/presentation/bloc/library/library_event.dart';
import 'package:vinyl/presentation/bloc/library/library_state.dart';
import 'package:vinyl/presentation/widgets/album_art_widget.dart';
import 'package:vinyl/services/stream_playlists_service.dart';

class AddToPlaylistSheet extends StatelessWidget {
  final Song song;
  final bool? isStream;

  const AddToPlaylistSheet({
    super.key,
    required this.song,
    this.isStream,
  });

  static void show(BuildContext context, Song song, {bool? isStream}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddToPlaylistSheet(
        song: song,
        isStream: isStream,
      ),
    );
  }

  bool get _effectiveIsStream => isStream ?? SongOrigin.isStream(song);

  void _createNewPlaylistAndAdd(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          _effectiveIsStream ? 'Create Stream Playlist' : 'Create New Playlist',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _effectiveIsStream
                ? 'Stream Playlist Title (e.g. Chill Beats)'
                : 'Playlist Title (e.g. My Favorites)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                if (_effectiveIsStream) {
                  final playlist = await StreamPlaylistsService.instance.createPlaylist(name);
                  await StreamPlaylistsService.instance.addSongToPlaylist(playlist.id, song);
                  Fluttertoast.showToast(
                    msg: 'Added "${song.title}" to $name',
                    toastLength: Toast.LENGTH_SHORT,
                  );
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (context.mounted) Navigator.pop(context);
                } else {
                  final libraryBloc = context.read<LibraryBloc>();
                  libraryBloc.add(CreatePlaylistEvent(name));
                  Future.delayed(const Duration(milliseconds: 300), () {
                    final state = libraryBloc.state;
                    if (state is LibraryLoaded) {
                      final created = state.playlists.firstWhere(
                        (p) => p.name.toLowerCase() == name.toLowerCase(),
                        orElse: () => state.playlists.isNotEmpty
                            ? state.playlists.last
                            : PlaylistModel(
                                id: 0,
                                name: name,
                                dateCreated: DateTime.now(),
                                dateModified: DateTime.now(),
                              ),
                      );
                      if (created.id > 0) {
                        libraryBloc.add(AddSongToPlaylistEvent(created.id, song));
                      }
                    }
                  });
                  Fluttertoast.showToast(
                    msg: 'Added "${song.title}" to $name',
                    toastLength: Toast.LENGTH_SHORT,
                  );
                  Navigator.pop(dialogCtx);
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Create & Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Song Info Header
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AlbumArtWidget(
                    albumArt: song.albumArt,
                    width: 46,
                    height: 46,
                    fallbackIcon: Icons.music_note_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _effectiveIsStream ? 'Add to Stream Playlist' : 'Add to Playlist',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_effectiveIsStream) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'STREAM',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${song.title} • ${song.artist}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // New Playlist Button
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              title: Text(
                _effectiveIsStream ? 'New Stream Playlist' : 'New Playlist',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
              subtitle: Text(
                _effectiveIsStream
                    ? 'Create a streaming playlist with this song'
                    : 'Create a local playlist with this song',
                style: GoogleFonts.outfit(fontSize: 12),
              ),
              onTap: () => _createNewPlaylistAndAdd(context),
            ),
            const SizedBox(height: 8),

            // Playlists List (Stream playlists vs Local library playlists)
            Flexible(
              child: _effectiveIsStream
                  ? _buildStreamPlaylistsList(context, theme, isDark)
                  : _buildLocalPlaylistsList(context, theme, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamPlaylistsList(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return StreamBuilder<List<PlaylistModel>>(
      stream: StreamPlaylistsService.instance.onPlaylistsChanged,
      initialData: StreamPlaylistsService.instance.playlists,
      builder: (context, snapshot) {
        final playlists = snapshot.data ?? StreamPlaylistsService.instance.playlists;

        if (playlists.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No stream playlists created yet.\nTap "New Stream Playlist" above to start your collection.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: playlists.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
          itemBuilder: (ctx, index) {
            final playlist = playlists[index];
            final alreadyIn = StreamPlaylistsService.instance.isSongInPlaylist(playlist.id, song.id);

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF262632) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.playlist_play_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              title: Text(
                playlist.name,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${playlist.songs.length} stream tracks',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: alreadyIn
                  ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20)
                  : const Icon(Icons.add_rounded, size: 20),
              onTap: () async {
                final added = await StreamPlaylistsService.instance.addSongToPlaylist(playlist.id, song);
                Fluttertoast.showToast(
                  msg: added
                      ? 'Added to "${playlist.name}"'
                      : 'Already in "${playlist.name}"',
                  toastLength: Toast.LENGTH_SHORT,
                );
                if (context.mounted) Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLocalPlaylistsList(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, state) {
        final playlists = state is LibraryLoaded
            ? state.playlists
            : const <PlaylistModel>[];

        if (playlists.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No existing playlists. Tap "New Playlist" above to create one.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: playlists.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
          itemBuilder: (ctx, index) {
            final playlist = playlists[index];
            final isFav = playlist.name.toLowerCase() == 'favorites';
            final alreadyIn = playlist.songs.any((s) => s.id == song.id);

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isFav
                      ? Colors.redAccent.withValues(alpha: 0.15)
                      : (isDark ? const Color(0xFF262632) : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isFav ? Icons.favorite_rounded : Icons.playlist_play_rounded,
                  color: isFav ? Colors.redAccent : theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              title: Text(
                playlist.name,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${playlist.songs.length} tracks',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: alreadyIn
                  ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20)
                  : const Icon(Icons.add_rounded, size: 20),
              onTap: () {
                context.read<LibraryBloc>().add(
                      AddSongToPlaylistEvent(playlist.id, song),
                    );
                Fluttertoast.showToast(
                  msg: alreadyIn
                      ? 'Already in "${playlist.name}"'
                      : 'Added to "${playlist.name}"',
                  toastLength: Toast.LENGTH_SHORT,
                );
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}
