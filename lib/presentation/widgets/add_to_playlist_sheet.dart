import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinyl/data/models/playlist_model.dart';
import 'package:vinyl/data/models/song_model.dart';
import 'package:vinyl/presentation/bloc/library/library_bloc.dart';
import 'package:vinyl/presentation/bloc/library/library_event.dart';
import 'package:vinyl/presentation/bloc/library/library_state.dart';
import 'package:vinyl/presentation/widgets/album_art_widget.dart';

class AddToPlaylistSheet extends StatelessWidget {
  final Song song;

  const AddToPlaylistSheet({super.key, required this.song});

  static void show(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddToPlaylistSheet(song: song),
    );
  }

  void _createNewPlaylistAndAdd(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          'Create New Playlist',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist Title (e.g. My Favorites)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final libraryBloc = context.read<LibraryBloc>();
                libraryBloc.add(CreatePlaylistEvent(name));
                // Delay slightly to let the new playlist register, then add the song
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
                Navigator.pop(context); // close sheet
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
                      Text(
                        'Add to Playlist',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                'New Playlist',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
              subtitle: Text(
                'Create a new playlist with this song',
                style: GoogleFonts.outfit(fontSize: 12),
              ),
              onTap: () => _createNewPlaylistAndAdd(context),
            ),
            const SizedBox(height: 8),

            // Existing Playlists List
            Flexible(
              child: BlocBuilder<LibraryBloc, LibraryState>(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
