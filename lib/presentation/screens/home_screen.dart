import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';
import 'package:pixel_player/presentation/widgets/album_art_widget.dart';
import 'package:pixel_player/presentation/screens/library_screen.dart';
import 'package:pixel_player/presentation/screens/player_screen.dart';
import 'package:pixel_player/presentation/screens/playlists_screen.dart';
import 'package:pixel_player/presentation/screens/settings_screen.dart';

import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/services/audio_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const LibraryScreen(),
    const PlaylistsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _MiniPlayerDock(),
          NavigationBar(
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
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is PlayerPlaying && current is PlayerPlaying) {
          return previous.song.id != current.song.id;
        }
        if (previous is PlayerPaused && current is PlayerPaused) {
          return previous.song.id != current.song.id;
        }
        return true;
      },
      builder: (context, state) {
        if (state is PlayerInitial || state is PlayerStopped) {
          return const SizedBox();
        }

        Song? currentSong;
        bool isPlaying = false;
        bool isLoading = false;
        final isActuallyPlaying = (state is PlayerPlaying) && getIt<AudioPlayerService>().isPlaying;
        final isActuallyLoading = (state is PlayerLoading) && getIt<AudioPlayerService>().isPlaying;

        if (state is PlayerPlaying) {
          currentSong = state.song;
          isPlaying = isActuallyPlaying;
        } else if (state is PlayerPaused) {
          currentSong = state.song;
          isPlaying = false;
        } else if (state is PlayerLoading) {
          currentSong = state.song;
          isLoading = isActuallyLoading;
        }

        if (currentSong == null) return const SizedBox();
        final song = currentSong;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayerScreen(song: song),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF232330)
                      : const Color(0xFFF2F2F7),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF323242) : Colors.black12,
                      width: 0.8,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    AlbumArtWidget(
                      albumArt: song.albumArt,
                      width: 44,
                      height: 44,
                      borderRadius: BorderRadius.circular(10),
                      fallbackIcon: Icons.music_note_rounded,
                      iconSize: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            song.artist,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
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
              StreamBuilder<Duration>(
                stream: getIt<AudioPlayerService>().positionStream,
                builder: (context, snapshot) {
                  final livePos = snapshot.data ?? Duration.zero;
                  final durationMs = song.duration.inMilliseconds.toDouble();
                  final progress = durationMs > 0
                      ? (livePos.inMilliseconds.toDouble() / durationMs)
                          .clamp(0.0, 1.0)
                      : 0.0;

                  return LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.5,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
