import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/core/utils/duration_formatter.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';
import 'package:pixel_player/presentation/bloc/library/library_event.dart';
import 'package:pixel_player/presentation/bloc/library/library_state.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/screens/player_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search & Scan Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (query) {
                            context
                                .read<LibraryBloc>()
                                .add(SearchSongsEvent(query));
                          },
                          decoration: InputDecoration(
                            hintText: 'Search songs, artists, albums...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF262632)
                                : Colors.grey.shade200,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.find_in_page_rounded),
                        tooltip: 'Scan Local Device',
                        onPressed: () {
                          context
                              .read<LibraryBloc>()
                              .add(const ScanStorageEvent());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Category Chips
                  BlocBuilder<LibraryBloc, LibraryState>(
                    builder: (context, state) {
                      String selectedCategory = 'All';
                      if (state is LibraryLoaded) {
                        selectedCategory = state.selectedCategory;
                      }

                      final categories = ['All', 'Albums', 'Artists', 'Playlists'];
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: categories.map((cat) {
                            final isSelected = selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                selectedColor: theme.colorScheme.primary,
                                labelStyle: GoogleFonts.outfit(
                                  color: isSelected
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                onSelected: (sel) {
                                  context
                                      .read<LibraryBloc>()
                                      .add(SelectCategoryEvent(cat));
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Main Songs List
            Expanded(
              child: BlocBuilder<LibraryBloc, LibraryState>(
                builder: (context, state) {
                  if (state is LibraryLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (state is LibraryLoaded) {
                    final songs = state.displayedSongs;
                    if (songs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_off_rounded,
                              size: 64,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tracks found',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the scan icon to scan your local storage',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: songs.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return _SongListTile(
                          song: song,
                          onTap: () {
                            context.read<PlayerBloc>().add(
                                  PlaySongEvent(song, queue: songs),
                                );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(song: song),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }

                  if (state is LibraryError) {
                    return Center(
                      child: Text('Error loading library: ${state.message}'),
                    );
                  }

                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongListTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SongListTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E26) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 50,
            height: 50,
            child: song.albumArt != null
                ? CachedNetworkImage(
                    imageUrl: song.albumArt!,
                    fit: BoxFit.cover,
                    errorWidget: (ctx, url, err) => Container(
                      color: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.music_note_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  )
                : Container(
                    color: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.music_note_rounded,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
          ),
        ),
        title: Text(
          song.title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${song.artist} • ${song.album}',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatDuration(song.duration),
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.play_arrow_rounded, color: Color(0xFF00E676)),
          ],
        ),
      ),
    );
  }
}
