import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/models/playlist_model.dart';
import 'package:pixel_player/core/utils/duration_formatter.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';
import 'package:pixel_player/presentation/bloc/library/library_event.dart';
import 'package:pixel_player/presentation/bloc/library/library_state.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/screens/player_screen.dart';
import 'package:pixel_player/presentation/widgets/folder_picker_dialog.dart';
import 'package:pixel_player/presentation/widgets/download_dialog.dart';

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
                        icon: const Icon(Icons.create_new_folder_rounded),
                        tooltip: 'Add Custom Folder',
                        onPressed: () => _showAddFolderDialog(context),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.cloud_download_rounded),
                        tooltip: 'Download from URL (YouTube/MP3)',
                        onPressed: () => DownloadDialog.show(context),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.find_in_page_rounded),
                        tooltip: 'Scan Device Storage',
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

                      final categories = ['All', 'Folders', 'Albums', 'Artists', 'Playlists'];
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

            // Main Content Area
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

                    if (state.selectedCategory == 'Folders') {
                      return _buildFolderList(context, songs);
                    }

                    if (state.selectedCategory == 'Albums') {
                      return _buildAlbumList(context, songs);
                    }

                    if (state.selectedCategory == 'Artists') {
                      return _buildArtistList(context, songs);
                    }

                    if (state.selectedCategory == 'Playlists') {
                      return _buildPlaylistList(context, state.playlists);
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

  Widget _buildFolderList(BuildContext context, List<Song> songs) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Group songs by folderName
    final Map<String, List<Song>> folderGroup = {};
    for (var song in songs) {
      final name = song.folderName;
      folderGroup.putIfAbsent(name, () => []).add(song);
    }

    final folderNames = folderGroup.keys.toList()..sort();

    return ListView.builder(
      itemCount: folderNames.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final folderName = folderNames[index];
        final folderSongs = folderGroup[folderName]!;
        final samplePath = folderSongs.first.folderPath;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: isDark ? const Color(0xFF1E1E26) : Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_special_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 26,
                ),
              ),
              title: Text(
                folderName,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '$samplePath • ${folderSongs.length} track${folderSongs.length > 1 ? 's' : ''}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 32),
                    color: theme.colorScheme.primary,
                    tooltip: 'Play All Folder Songs',
                    onPressed: () {
                      context.read<PlayerBloc>().add(
                            PlaySongEvent(folderSongs.first, queue: folderSongs),
                          );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(song: folderSongs.first),
                        ),
                      );
                    },
                  ),
                ],
              ),
              children: folderSongs.map((song) {
                return _SongListTile(
                  song: song,
                  onTap: () {
                    context.read<PlayerBloc>().add(
                          PlaySongEvent(song, queue: folderSongs),
                        );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(song: song),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumList(BuildContext context, List<Song> songs) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Map<String, List<Song>> albumGroup = {};
    for (var song in songs) {
      albumGroup.putIfAbsent(song.album, () => []).add(song);
    }

    final albumNames = albumGroup.keys.toList()..sort();

    return ListView.builder(
      itemCount: albumNames.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final albumName = albumNames[index];
        final albumSongs = albumGroup[albumName]!;
        final firstSong = albumSongs.first;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: isDark ? const Color(0xFF1E1E26) : Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: firstSong.albumArt != null
                      ? CachedNetworkImage(
                          imageUrl: firstSong.albumArt!,
                          fit: BoxFit.cover,
                          errorWidget: (ctx, url, err) => Container(
                            color: theme.colorScheme.primaryContainer,
                            child: Icon(Icons.album_rounded, color: theme.colorScheme.onPrimaryContainer),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.primaryContainer,
                          child: Icon(Icons.album_rounded, color: theme.colorScheme.onPrimaryContainer),
                        ),
                ),
              ),
              title: Text(
                albumName,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '${firstSong.artist} • ${albumSongs.length} track${albumSongs.length > 1 ? 's' : ''}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded, size: 32),
                color: theme.colorScheme.primary,
                tooltip: 'Play Album',
                onPressed: () {
                  context.read<PlayerBloc>().add(
                        PlaySongEvent(albumSongs.first, queue: albumSongs),
                      );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(song: albumSongs.first),
                    ),
                  );
                },
              ),
              children: albumSongs.map((song) {
                return _SongListTile(
                  song: song,
                  onTap: () {
                    context.read<PlayerBloc>().add(
                          PlaySongEvent(song, queue: albumSongs),
                        );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(song: song),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtistList(BuildContext context, List<Song> songs) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Map<String, List<Song>> artistGroup = {};
    for (var song in songs) {
      artistGroup.putIfAbsent(song.artist, () => []).add(song);
    }

    final artistNames = artistGroup.keys.toList()..sort();

    return ListView.builder(
      itemCount: artistNames.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final artistName = artistNames[index];
        final artistSongs = artistGroup[artistName]!;
        final albumsCount = artistSongs.map((s) => s.album).toSet().length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: isDark ? const Color(0xFF1E1E26) : Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.secondaryContainer,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: theme.colorScheme.onSecondaryContainer,
                  size: 28,
                ),
              ),
              title: Text(
                artistName,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '$albumsCount album${albumsCount > 1 ? 's' : ''} • ${artistSongs.length} track${artistSongs.length > 1 ? 's' : ''}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded, size: 32),
                color: theme.colorScheme.primary,
                tooltip: 'Play Artist Songs',
                onPressed: () {
                  context.read<PlayerBloc>().add(
                        PlaySongEvent(artistSongs.first, queue: artistSongs),
                      );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(song: artistSongs.first),
                    ),
                  );
                },
              ),
              children: artistSongs.map((song) {
                return _SongListTile(
                  song: song,
                  onTap: () {
                    context.read<PlayerBloc>().add(
                          PlaySongEvent(song, queue: artistSongs),
                        );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(song: song),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistList(BuildContext context, List<PlaylistModel> playlists) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final libraryState = context.watch<LibraryBloc>().state;
    final allSongs = libraryState is LibraryLoaded ? libraryState.allSongs : <Song>[];

    final recentlyAdded = List<Song>.from(allSongs)
      ..sort((a, b) => b.dateModified.compareTo(a.dateModified));
    final downloaded = allSongs.where((s) => !s.filePath.startsWith('http')).toList();

    return Column(
      children: [
        // SMART PLAYLISTS CARDS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Playlists',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (recentlyAdded.isNotEmpty) {
                          context.read<PlayerBloc>().add(
                                PlaySongEvent(recentlyAdded.first, queue: recentlyAdded),
                              );
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(song: recentlyAdded.first),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary),
                            const SizedBox(height: 8),
                            Text(
                              'Recently Added',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '${recentlyAdded.length} tracks',
                              style: GoogleFonts.outfit(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (downloaded.isNotEmpty) {
                          context.read<PlayerBloc>().add(
                                PlaySongEvent(downloaded.first, queue: downloaded),
                              );
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(song: downloaded.first),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.download_for_offline_rounded, color: theme.colorScheme.secondary),
                            const SizedBox(height: 8),
                            Text(
                              'Downloaded',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '${downloaded.length} tracks',
                              style: GoogleFonts.outfit(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Playlists (${playlists.length})',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Playlist'),
                onPressed: () => _showCreatePlaylistDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: playlists.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Playlists Created Yet',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "New Playlist" above to create your playlist and start adding your favorite songs!',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: playlists.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(8, 0, 8, 12),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.playlist_play_rounded,
                              color: theme.colorScheme.onTertiaryContainer,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            playlist.name,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            '${playlist.songs.length} track${playlist.songs.length == 1 ? '' : 's'}${playlist.description != null && playlist.description!.isNotEmpty ? ' • ${playlist.description}' : ''}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (playlist.songs.isNotEmpty)
                                IconButton(
                                  icon: const Icon(
                                      Icons.play_circle_fill_rounded,
                                      size: 32),
                                  color: theme.colorScheme.primary,
                                  tooltip: 'Play Playlist',
                                  onPressed: () {
                                    context.read<PlayerBloc>().add(
                                          PlaySongEvent(playlist.songs.first,
                                              queue: playlist.songs),
                                        );
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PlayerScreen(
                                            song: playlist.songs.first),
                                      ),
                                    );
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.redAccent, size: 22),
                                tooltip: 'Delete Playlist',
                                onPressed: () {
                                  context
                                      .read<LibraryBloc>()
                                      .add(DeletePlaylistEvent(playlist.id));
                                },
                              ),
                            ],
                          ),
                          children: playlist.songs.isEmpty
                              ? [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'Playlist is empty. Add songs by tapping the "+" icon next to any song!',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  )
                                ]
                              : playlist.songs.map((song) {
                                  return _SongListTile(
                                    song: song,
                                    onTap: () {
                                      context.read<PlayerBloc>().add(
                                            PlaySongEvent(song,
                                                queue: playlist.songs),
                                          );
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PlayerScreen(song: song),
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Create New Playlist',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Playlist Name',
                  hintText: 'e.g., Favorites, Chill Hits',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  context.read<LibraryBloc>().add(CreatePlaylistEvent(
                        name,
                        description: descController.text.trim(),
                      ));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showAddFolderDialog(BuildContext context) {
    final controller = TextEditingController(text: '/storage/emulated/0/Download');
    final libraryBloc = context.read<LibraryBloc>();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Add & Scan Custom Folder',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select or enter the directory path on your device to scan for music files:',
                    style: GoogleFonts.outfit(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: '/storage/emulated/0/Download',
                            labelText: 'Folder Path',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.folder_open_rounded),
                        tooltip: 'Browse Folders',
                        onPressed: () async {
                          final selected = await showDialog<String>(
                            context: dialogContext,
                            builder: (_) => FolderPickerDialog(
                              initialPath: controller.text.trim(),
                            ),
                          );
                          if (selected != null && selected.isNotEmpty) {
                            setDialogState(() {
                              controller.text = selected;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final path = controller.text.trim();
                    if (path.isNotEmpty) {
                      libraryBloc
                          .add(ScanStorageEvent(customPaths: [path]));
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Scan Folder'),
                ),
              ],
            );
          },
        );
      },
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'play_next') {
                  context.read<PlayerBloc>().add(InsertNextEvent(song));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Playing "${song.title}" next', style: GoogleFonts.outfit()),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else if (value == 'add_to_queue') {
                  context.read<PlayerBloc>().add(AddToQueueEvent(song));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added "${song.title}" to queue', style: GoogleFonts.outfit()),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else if (value == 'add_to_playlist') {
                  _showAddToPlaylistDialog(context, song);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'play_next',
                  child: Row(
                    children: [
                      const Icon(Icons.playlist_play_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text('Play Next', style: GoogleFonts.outfit()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'add_to_queue',
                  child: Row(
                    children: [
                      const Icon(Icons.queue_music_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text('Add to Queue', style: GoogleFonts.outfit()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'add_to_playlist',
                  child: Row(
                    children: [
                      const Icon(Icons.playlist_add_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text('Add to Playlist', style: GoogleFonts.outfit()),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _showAddToPlaylistDialog(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return BlocBuilder<LibraryBloc, LibraryState>(
          builder: (context, state) {
            final playlists =
                state is LibraryLoaded ? state.playlists : <PlaylistModel>[];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add to Playlist',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New Playlist'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showCreatePlaylistDialogStatic(context);
                        },
                      ),
                    ],
                  ),
                  Text(
                    song.title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Divider(height: 24),
                  if (playlists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No playlists yet. Tap "New Playlist" above to create one!',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = playlists[index];
                          final containsSong =
                              playlist.songs.any((s) => s.id == song.id);

                          return ListTile(
                            leading: Icon(
                              Icons.playlist_play_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(
                              playlist.name,
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('${playlist.songs.length} songs'),
                            trailing: containsSong
                                ? const Icon(Icons.check_circle_rounded,
                                    color: Colors.green)
                                : const Icon(Icons.add_circle_outline_rounded),
                            onTap: () {
                              context.read<LibraryBloc>().add(
                                    AddSongToPlaylistEvent(playlist.id, song),
                                  );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Added "${song.title}" to ${playlist.name}',
                                    style: GoogleFonts.outfit(),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static void _showCreatePlaylistDialogStatic(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final libraryBloc = context.read<LibraryBloc>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Create New Playlist',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Playlist Name',
                  hintText: 'e.g., Favorites, Chill Hits',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  libraryBloc.add(CreatePlaylistEvent(
                        name,
                        description: descController.text.trim(),
                      ));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
