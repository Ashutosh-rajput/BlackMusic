import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';
import 'package:pixel_player/presentation/screens/library_screen.dart';
import 'package:pixel_player/presentation/screens/player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const LibraryScreen(),
    const _PlaceholderView(title: 'Playlists', icon: Icons.queue_music_rounded),
    const _PlaceholderView(title: 'Settings', icon: Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
          // Persistent Mini Player Floating Dock
          Positioned(
            left: 12,
            right: 12,
            bottom: 75,
            child: const _MiniPlayerDock(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: isDark ? const Color(0xFF181820) : Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.playlist_play_outlined),
            selectedIcon: Icon(Icons.playlist_play_rounded),
            label: 'Playlists',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _MiniPlayerDock extends StatelessWidget {
  const _MiniPlayerDock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        if (state is PlayerInitial || state is PlayerStopped) {
          return const SizedBox();
        }

        Song? currentSong;
        bool isPlaying = false;

        if (state is PlayerPlaying) {
          currentSong = state.song;
          isPlaying = true;
        } else if (state is PlayerPaused) {
          currentSong = state.song;
          isPlaying = false;
        } else if (state is PlayerLoading) {
          currentSong = state.song;
        }

        if (currentSong == null) return const SizedBox();

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayerScreen(song: currentSong!),
              ),
            );
          },
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2B2B38).withOpacity(0.95)
                  : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: currentSong.albumArt != null
                        ? CachedNetworkImage(
                            imageUrl: currentSong.albumArt!,
                            fit: BoxFit.cover,
                            errorWidget: (ctx, url, err) => Container(
                              color: theme.colorScheme.primaryContainer,
                              child: const Icon(Icons.music_note, size: 24),
                            ),
                          )
                        : Container(
                            color: theme.colorScheme.primaryContainer,
                            child: const Icon(Icons.music_note, size: 24),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSong.title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        currentSong.artist,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  onPressed: () {
                    if (isPlaying) {
                      context.read<PlayerBloc>().add(const PauseEvent());
                    } else {
                      context.read<PlayerBloc>().add(const ResumeEvent());
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: () {
                    context.read<PlayerBloc>().add(const NextSongEvent());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderView({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '$title Feature',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Privacy-first audio player module',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
