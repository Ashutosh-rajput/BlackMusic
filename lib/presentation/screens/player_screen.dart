import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/core/utils/duration_formatter.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';

class PlayerScreen extends StatefulWidget {
  final Song song;

  const PlayerScreen({required this.song, super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    final playerState = context.read<PlayerBloc>().state;
    if (playerState is PlayerPlaying && playerState.song.id == widget.song.id) {
      _rotationController.repeat();
    } else {
      context.read<PlayerBloc>().add(PlaySongEvent(widget.song));
      _rotationController.repeat();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _syncAnimation(PlayerState state) {
    if (state is PlayerPlaying) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocConsumer<PlayerBloc, PlayerState>(
      listener: (context, state) => _syncAnimation(state),
      builder: (context, state) {
        Song currentSong = widget.song;
        Duration position = Duration.zero;
        Duration duration = widget.song.duration;
        bool isPlaying = false;
        bool isShuffle = false;
        bool isRepeat = false;

        if (state is PlayerPlaying) {
          currentSong = state.song;
          position = state.position;
          duration = state.duration.inMilliseconds > 0
              ? state.duration
              : currentSong.duration;
          isPlaying = true;
          isShuffle = state.isShuffle;
          isRepeat = state.isRepeat;
        } else if (state is PlayerPaused) {
          currentSong = state.song;
          position = state.position;
          duration = state.duration.inMilliseconds > 0
              ? state.duration
              : currentSong.duration;
          isPlaying = false;
          isShuffle = state.isShuffle;
          isRepeat = state.isRepeat;
        }

        final double sliderMax = duration.inMilliseconds.toDouble() > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;
        final double sliderValue = position.inMilliseconds
            .toDouble()
            .clamp(0.0, sliderMax);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'NOW PLAYING',
              style: GoogleFonts.outfit(
                fontSize: 14,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showSpeedDialog(context),
              ),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 20),
              // Album Art with Vinyl Spinning Effect
              Expanded(
                child: Center(
                  child: RotationTransition(
                    turns: _rotationController,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.6)
                                : theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: currentSong.albumArt != null
                            ? CachedNetworkImage(
                                imageUrl: currentSong.albumArt!,
                                fit: BoxFit.cover,
                                placeholder: (ctx, url) => Container(
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  child: const Icon(Icons.music_note, size: 80),
                                ),
                                errorWidget: (ctx, url, err) => Container(
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  child: const Icon(Icons.music_note, size: 80),
                                ),
                              )
                            : Container(
                                color: theme.colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.disc_full_rounded,
                                  size: 140,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Song Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Text(
                      currentSong.title,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${currentSong.artist} • ${currentSong.album}',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Progress Slider & Timers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Slider(
                      min: 0,
                      max: sliderMax,
                      value: sliderValue,
                      onChanged: (value) {
                        context.read<PlayerBloc>().add(
                              SeekEvent(Duration(milliseconds: value.toInt())),
                            );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatDuration(position),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            formatDuration(duration),
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
              ),
              const SizedBox(height: 20),
              // Control Action Buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 40, left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: isShuffle
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      iconSize: 26,
                      onPressed: () {
                        context.read<PlayerBloc>().add(const ToggleShuffleEvent());
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded),
                      iconSize: 42,
                      onPressed: () {
                        context.read<PlayerBloc>().add(const PreviousSongEvent());
                      },
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                        iconSize: 38,
                        onPressed: () {
                          if (isPlaying) {
                            context.read<PlayerBloc>().add(const PauseEvent());
                          } else {
                            context.read<PlayerBloc>().add(const ResumeEvent());
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded),
                      iconSize: 42,
                      onPressed: () {
                        context.read<PlayerBloc>().add(const NextSongEvent());
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.repeat_rounded,
                        color: isRepeat
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      iconSize: 26,
                      onPressed: () {
                        context.read<PlayerBloc>().add(const ToggleRepeatEvent());
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSpeedDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Playback Speed',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [0.75, 1.0, 1.25, 1.5, 2.0].map((rate) {
                  return ChoiceChip(
                    label: Text('${rate}x'),
                    selected: false,
                    onSelected: (selected) {
                      context
                          .read<PlayerBloc>()
                          .add(SetPlaybackRateEvent(rate));
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
