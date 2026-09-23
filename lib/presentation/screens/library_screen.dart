import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/services/settings_service.dart';
import 'package:pixel_player/services/download_service.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/models/youtube_video_item.dart';
import 'package:pixel_player/data/models/jiosaavn_item.dart';
import 'package:pixel_player/core/utils/jiosaavn_decoder.dart';
import 'package:pixel_player/core/utils/duration_formatter.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';
import 'package:pixel_player/presentation/bloc/library/library_event.dart';
import 'package:pixel_player/presentation/bloc/library/library_state.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';
import 'package:pixel_player/presentation/screens/player_screen.dart';
import 'package:pixel_player/presentation/screens/category_detail_screen.dart';
import 'package:pixel_player/presentation/widgets/album_art_widget.dart';
import 'package:pixel_player/presentation/widgets/folder_picker_dialog.dart';
import 'package:pixel_player/presentation/widgets/download_queue_sheet.dart';
import 'package:pixel_player/presentation/widgets/download_queue_snackbar.dart';
import 'package:pixel_player/presentation/bloc/theme/theme_cubit.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _showHistory = _searchFocusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_searchFocusNode.hasFocus,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
          if (mounted) setState(() => _showHistory = false);
        }
      },
      child: Scaffold(
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
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          textInputAction: TextInputAction.search,
                          onChanged: (query) {
                            if (query.trim().isEmpty) {
                              context
                                  .read<LibraryBloc>()
                                  .add(const SearchSongsEvent(''));
                            }
                            setState(() {});
                          },
                          onSubmitted: (query) {
                            final q = query.trim();
                            if (q.isNotEmpty) {
                              context
                                  .read<LibraryBloc>()
                                  .add(SearchSongsEvent(q));
                            }
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Search songs, artists, albums, YouTube...',
                            prefixIcon: IconButton(
                              icon: const Icon(Icons.search_rounded),
                              tooltip: 'Search',
                              onPressed: () {
                                final q = _searchController.text.trim();
                                if (q.isNotEmpty) {
                                  _searchFocusNode.unfocus();
                                  context
                                      .read<LibraryBloc>()
                                      .add(SearchSongsEvent(q));
                                }
                              },
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      context
                                          .read<LibraryBloc>()
                                          .add(const SearchSongsEvent(''));
                                      setState(() {});
                                    },
                                  )
                                : null,
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
                        tooltip: 'Open download queue',
                        onPressed: () => DownloadQueueSheet.show(context),
                      ),
                    ],
                  ),
                  if (_showHistory) _buildSearchHistoryOverlay(context),
                  const SizedBox(height: 14),
                  // Category Chips
                  BlocBuilder<LibraryBloc, LibraryState>(
                    builder: (context, state) {
                      String selectedCategory = 'All';
                      if (state is LibraryLoaded) {
                        selectedCategory = state.selectedCategory;
                      }

                      final categories = [
                        'All',
                        'Folders',
                        'Albums',
                        'Artists'
                      ];
                      return Row(
                        children: categories.map((cat) {
                          final isSelected = selectedCategory == cat;
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: ChoiceChip(
                                label: Center(
                                  child: Text(
                                    cat,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: theme.colorScheme.primary,
                                showCheckmark: false,
                                labelStyle: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                onSelected: (_) {
                                  context.read<LibraryBloc>().add(
                                        SelectCategoryEvent(cat),
                                      );
                                },
                              ),
                            ),
                          );
                        }).toList(),
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
                    if (state.searchQuery.trim().isNotEmpty) {
                      return _buildSearchResultsView(context, state, theme);
                    }

                    final songs = state.displayedSongs;
                    if (songs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_off_rounded,
                              size: 64,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No music yet',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Use the search bar or download icon above to find music, or share a song or playlist from another app to add it here',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
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
    ),
  );
}

  Widget _buildSearchHistoryOverlay(BuildContext context) {
    final settings = getIt<SettingsService>();
    final history = settings.getSearchHistory();
    if (history.isEmpty || !settings.saveSearchHistory) return const SizedBox();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262632) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded,
                      size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Recent Searches',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600),
                  ),
                ],
              ),
              InkWell(
                onTap: () async {
                  await settings.clearSearchHistory();
                  setState(() {});
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text('Clear All',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: history.take(8).map((query) {
              return ActionChip(
                avatar: const Icon(Icons.history_rounded, size: 14),
                label: Text(query, style: GoogleFonts.outfit(fontSize: 12)),
                backgroundColor:
                    isDark ? const Color(0xFF1E1E28) : Colors.grey.shade100,
                onPressed: () {
                  _searchController.text = query;
                  _searchFocusNode.unfocus();
                  context.read<LibraryBloc>().add(SearchSongsEvent(query));
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsView(
      BuildContext context, LibraryLoaded state, ThemeData theme) {
    final localSongs = state.displayedSongs;
    final onlineItems = state.onlineResults;
    final jiosaavnItems = state.jiosaavnResults;
    final isSearchingOnline = state.isSearchingOnline;

    if (localSongs.isEmpty && onlineItems.isEmpty && jiosaavnItems.isEmpty && !isSearchingOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "${state.searchQuery}"',
              style:
                  GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (localSongs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '🎵 Local Songs (${localSongs.length})',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ...localSongs.map((song) => _SongListTile(
                song: song,
                onTap: () {
                  context
                      .read<PlayerBloc>()
                      .add(PlaySongEvent(song, queue: localSongs));
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PlayerScreen(song: song)),
                  );
                },
              )),
          const SizedBox(height: 16),
        ],
        if (isSearchingOnline || onlineItems.isNotEmpty || jiosaavnItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  '🌐 Online Results',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                if (isSearchingOnline) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (jiosaavnItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🎶 JioSaavn',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${jiosaavnItems.length} results',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          ...jiosaavnItems.map((item) => _JioSaavnResultTile(item: item)),
          const SizedBox(height: 12),
        ],
        if (onlineItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '▶ YouTube',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${onlineItems.length} results',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          ...onlineItems.map((item) => _OnlineResultTile(item: item)),
        ],
      ],
    );
  }

  void _showAddFolderDialog(BuildContext context) async {
    final bloc = context.read<LibraryBloc>();
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => const FolderPickerDialog(),
    );
    if (selected != null && selected.isNotEmpty) {
      bloc.add(ScanStorageEvent(customPaths: [selected]));
    }
  }

  Widget _buildFolderList(BuildContext context, List<Song> songs) {
    Map<String, List<Song>> folderMap = {};
    for (var song in songs) {
      final parts = song.filePath.split(RegExp(r'[/\\]'));
      final folderName = parts.length > 1 ? parts[parts.length - 2] : 'Root';
      folderMap.putIfAbsent(folderName, () => []).add(song);
    }

    final folders = folderMap.entries.toList();
    if (folders.isEmpty) {
      return const Center(child: Text('No folders found'));
    }

    return ListView.builder(
      itemCount: folders.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final entry = folders[index];
        return ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.folder_rounded),
          ),
          title: Text(
            entry.key,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${entry.value.length} songs',
            style: GoogleFonts.outfit(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryDetailScreen(
                  title: entry.key,
                  subtitle: 'Folder',
                  icon: Icons.folder_rounded,
                  songs: entry.value,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAlbumList(BuildContext context, List<Song> songs) {
    Map<String, List<Song>> albumMap = {};
    for (var song in songs) {
      albumMap.putIfAbsent(song.album, () => []).add(song);
    }

    final albums = albumMap.entries.toList();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final entry = albums[index];
        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryDetailScreen(
                  title: entry.key,
                  subtitle: 'Album',
                  icon: Icons.album_rounded,
                  songs: entry.value,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.album_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              Text(
                '${entry.value.length} songs',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtistList(BuildContext context, List<Song> songs) {
    Map<String, List<Song>> artistMap = {};
    for (var song in songs) {
      artistMap.putIfAbsent(song.artist, () => []).add(song);
    }

    final artists = artistMap.entries.toList();
    return ListView.builder(
      itemCount: artists.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final entry = artists[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            entry.key,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${entry.value.length} songs',
            style: GoogleFonts.outfit(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryDetailScreen(
                  title: entry.key,
                  subtitle: 'Artist',
                  icon: Icons.person_rounded,
                  songs: entry.value,
                ),
              ),
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

  const _SongListTile({
    required this.song,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artDimension = context.select<ThemeCubit, double>(
      (cubit) => cubit.state.albumArtDimension,
    );

    final isCurrentSong = context.select<PlayerBloc, bool>((bloc) {
      final s = bloc.state;
      return (s is PlayerPlaying && s.song.id == song.id) ||
          (s is PlayerPaused && s.song.id == song.id);
    });
    final isPlaying = context.select<PlayerBloc, bool>((bloc) {
      final s = bloc.state;
      return s is PlayerPlaying && s.song.id == song.id;
    });

    final titleColor =
        isCurrentSong ? theme.colorScheme.primary : theme.colorScheme.onSurface;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: AlbumArtWidget(
        albumArt: song.albumArt,
        width: artDimension,
        height: artDimension,
        borderRadius: BorderRadius.circular(8),
        fallbackIcon:
            isCurrentSong ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
        fallbackBgColor: isCurrentSong
            ? theme.colorScheme.primary
            : theme.colorScheme.primaryContainer,
        fallbackIconColor: isCurrentSong
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onPrimaryContainer,
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.outfit(
          fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.w600,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        '${song.artist} • ${song.album}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.outfit(
          color: isCurrentSong
              ? theme.colorScheme.primary.withValues(alpha: 0.8)
              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlaying)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: _PlayingEqualizerBars(),
            )
          else if (isCurrentSong)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.pause_circle_rounded,
                  color: theme.colorScheme.primary, size: 20),
            ),
          Text(
            formatDuration(song.duration),
            style: GoogleFonts.outfit(
              color: isCurrentSong
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _PlayingEqualizerBars extends StatefulWidget {
  const _PlayingEqualizerBars();

  @override
  State<_PlayingEqualizerBars> createState() => _PlayingEqualizerBarsState();
}

class _PlayingEqualizerBarsState extends State<_PlayingEqualizerBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final value = _animController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar((8 + (value * 12)).clamp(4.0, 20.0), color),
            const SizedBox(width: 2.5),
            _bar((18 - (value * 12)).clamp(4.0, 20.0), color),
            const SizedBox(width: 2.5),
            _bar((6 + (value * 14)).clamp(4.0, 20.0), color),
            const SizedBox(width: 2.5),
            _bar((16 - (value * 10)).clamp(4.0, 20.0), color),
          ],
        );
      },
    );
  }

  Widget _bar(double height, Color color) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

class _OnlineResultTile extends StatelessWidget {
  final YouTubeVideoItem item;

  const _OnlineResultTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final downloadService = getIt<DownloadService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ValueListenableBuilder<List<ActiveDownload>>(
        valueListenable: downloadService.downloadQueueNotifier,
        builder: (context, queue, _) {
          final active = downloadService.getDownloadByUrl(item.url);

          Widget trailingWidget;
          if (active == null) {
            trailingWidget = IconButton.filledTonal(
              icon: const Icon(Icons.download_rounded, size: 20),
              tooltip: 'Download Track',
              onPressed: () => _triggerDownload(context, downloadService),
            );
          } else if (active.isCompleted) {
            trailingWidget = const IconButton(
              icon: Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 24),
              tooltip: 'Downloaded',
              onPressed: null,
            );
          } else if (active.isDownloading) {
            trailingWidget = Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    value: active.progress > 0 ? active.progress : null,
                    strokeWidth: 3,
                  ),
                ),
                Text(
                  '${(active.progress * 100).toInt()}%',
                  style: GoogleFonts.outfit(
                      fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            );
          } else if (active.isQueued) {
            trailingWidget = const Chip(
              avatar:
                  Icon(Icons.schedule_rounded, size: 14, color: Colors.orange),
              label: Text('Queued',
                  style: TextStyle(fontSize: 11, color: Colors.orange)),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          } else {
            trailingWidget = IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.red, size: 20),
              tooltip: 'Retry Download',
              onPressed: () => _triggerDownload(context, downloadService),
            );
          }

          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: item.thumbnailUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.music_note_rounded),
              ),
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              '${item.author} • ${formatDuration(item.duration)}',
              style: GoogleFonts.outfit(fontSize: 12),
            ),
            trailing: trailingWidget,
            onTap: () => _triggerDownload(context, downloadService),
          );
        },
      ),
    );
  }

  void _triggerDownload(BuildContext context, DownloadService service) {
    service.enqueueDownload(
      url: item.url,
      title: item.title,
      artist: item.author,
      albumArt: item.thumbnailUrl,
      duration: item.duration,
    );
    showDownloadQueuedSnackBar(
      context,
      title: item.title,
      onViewQueue: () => DownloadQueueSheet.show(context),
    );
  }
}

// ── JioSaavn result tile ──────────────────────────────────────────────────────

class _JioSaavnResultTile extends StatelessWidget {
  final JioSaavnItem item;

  const _JioSaavnResultTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final downloadService = getIt<DownloadService>();
    final theme = Theme.of(context);

    IconData typeIcon;
    if (item.isAlbum) {
      typeIcon = Icons.album_rounded;
    } else if (item.isArtist) {
      typeIcon = Icons.person_rounded;
    } else if (item.isPlaylist) {
      typeIcon = Icons.queue_music_rounded;
    } else {
      typeIcon = Icons.music_note_rounded;
    }

    String subtitleText = item.subtitle;
    if (item.isSong && item.duration != null) {
      final secs = int.tryParse(item.duration ?? '0') ?? 0;
      subtitleText += ' • ${formatDuration(Duration(seconds: secs))}';
    } else if ((item.isAlbum || item.isPlaylist) && item.songCount != null) {
      subtitleText = '${item.songCount} songs';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item.imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 50,
                    height: 50,
                    color: theme.colorScheme.primaryContainer,
                    child: Icon(typeIcon, color: theme.colorScheme.onPrimaryContainer),
                  ),
                )
              : Container(
                  width: 50,
                  height: 50,
                  color: theme.colorScheme.primaryContainer,
                  child: Icon(typeIcon, color: theme.colorScheme.onPrimaryContainer),
                ),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.type.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF6B35),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                subtitleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: item.isSong && (item.directMediaUrl != null || item.encryptedMediaUrl != null)
            ? ValueListenableBuilder<List<ActiveDownload>>(
                valueListenable: downloadService.downloadQueueNotifier,
                builder: (context, queue, _) {
                  final directUrl = item.directMediaUrl ?? JioSaavnDecoder.decryptMediaUrl(item.encryptedMediaUrl);
                  final active = queue.where((d) =>
                      (directUrl != null && d.url == directUrl) ||
                      (item.encryptedMediaUrl != null &&
                          (d.url == item.encryptedMediaUrl || d.url == 'jiosaavn:${item.encryptedMediaUrl}')) ||
                      d.id == item.id).isNotEmpty
                      ? queue.lastWhere((d) =>
                          (directUrl != null && d.url == directUrl) ||
                          (item.encryptedMediaUrl != null &&
                              (d.url == item.encryptedMediaUrl || d.url == 'jiosaavn:${item.encryptedMediaUrl}')) ||
                          d.id == item.id)
                      : null;

                  if (active == null) {
                    return IconButton.filledTonal(
                      icon: const Icon(Icons.download_rounded, size: 20),
                      tooltip: 'Download from JioSaavn',
                      onPressed: () => _triggerJioSaavnDownload(context, downloadService),
                    );
                  } else if (active.isCompleted) {
                    return const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24);
                  } else if (active.isDownloading) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            value: active.progress > 0 ? active.progress : null,
                            strokeWidth: 3,
                          ),
                        ),
                        Text(
                          '${(active.progress * 100).toInt()}%',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  } else if (active.isQueued) {
                    return const Chip(
                      avatar: Icon(Icons.schedule_rounded, size: 14, color: Colors.orange),
                      label: Text('Queued', style: TextStyle(fontSize: 11, color: Colors.orange)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  } else {
                    return IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.red, size: 20),
                      tooltip: 'Retry',
                      onPressed: () => _triggerJioSaavnDownload(context, downloadService),
                    );
                  }
                },
              )
            : item.isAlbum || item.isPlaylist
                ? IconButton.filledTonal(
                    icon: const Icon(Icons.download_for_offline_rounded, size: 20),
                    tooltip: 'Download all from JioSaavn',
                    onPressed: () => _triggerJioSaavnDownload(context, downloadService),
                  )
                : null,
        onTap: () => _triggerJioSaavnDownload(context, downloadService),
      ),
    );
  }

  void _triggerJioSaavnDownload(BuildContext context, DownloadService service) {
    String url;
    if (item.directMediaUrl != null && item.directMediaUrl!.isNotEmpty) {
      url = item.directMediaUrl!;
    } else if (item.encryptedMediaUrl != null) {
      final decrypted = JioSaavnDecoder.decryptMediaUrl(item.encryptedMediaUrl);
      url = decrypted ?? 'jiosaavn:${item.encryptedMediaUrl}';
    } else if (item.isAlbum) {
      url = 'jiosaavn-album:${item.token}';
    } else if (item.isPlaylist) {
      url = 'jiosaavn-playlist:${item.token}';
    } else {
      url = 'jiosaavn-token:${item.token}';
    }
    final secs = int.tryParse(item.duration ?? '0') ?? 0;
    service.enqueueDownload(
      url: url,
      title: item.title,
      artist: item.subtitle,
      album: item.isAlbum ? item.title : (item.subtitle.isNotEmpty ? item.subtitle : 'JioSaavn'),
      albumArt: item.imageUrl,
      duration: secs > 0 ? Duration(seconds: secs) : null,
    );
    showDownloadQueuedSnackBar(
      context,
      title: item.title,
      onViewQueue: () => DownloadQueueSheet.show(context),
    );
  }
}
