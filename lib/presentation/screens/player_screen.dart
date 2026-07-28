import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/core/utils/duration_formatter.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';
import 'package:pixel_player/presentation/bloc/library/library_event.dart';
import 'package:pixel_player/presentation/bloc/library/library_state.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/services/settings_service.dart';
import 'package:pixel_player/presentation/widgets/album_art_widget.dart';
import 'package:pixel_player/presentation/widgets/queue_bottom_sheet.dart';
import 'package:pixel_player/presentation/widgets/sleep_timer_dialog.dart';

class PlayerScreen extends StatefulWidget {
  final Song song;

  const PlayerScreen({required this.song, super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _waveController;
  bool _isDragging = false;
  double _dragPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    final playerState = context.read<PlayerBloc>().state;
    if (playerState is PlayerPlaying) {
      _rotationController.repeat();
      _waveController.repeat();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _syncAnimation(PlayerState state) {
    if (state is PlayerPlaying) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
      if (!_waveController.isAnimating) {
        _waveController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
      if (_waveController.isAnimating) {
        _waveController.stop();
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
        bool isLoading = false;
        bool isShuffle = false;
        String repeatMode = 'Off';

        if (state is PlayerPlaying) {
          currentSong = state.song;
          position = state.position;
          duration = state.duration.inMilliseconds > 0
              ? state.duration
              : currentSong.duration;
          isPlaying = true;
          isShuffle = state.isShuffle;
          repeatMode = state.repeatMode;
        } else if (state is PlayerPaused) {
          currentSong = state.song;
          position = state.position;
          duration = state.duration.inMilliseconds > 0
              ? state.duration
              : currentSong.duration;
          isPlaying = false;
          isShuffle = state.isShuffle;
          repeatMode = state.repeatMode;
        } else if (state is PlayerLoading) {
          if (state.song != null) {
            currentSong = state.song!;
          }
          duration = currentSong.duration;
          isLoading = true;
          isShuffle = state.isShuffle;
          repeatMode = state.repeatMode;
        }

        final double sliderMax = duration.inMilliseconds.toDouble() > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;
        final double sliderValue = _isDragging
            ? _dragPosition.clamp(0.0, sliderMax)
            : position.inMilliseconds.toDouble().clamp(0.0, sliderMax);

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
                icon: const Icon(Icons.queue_music_rounded),
                tooltip: 'Playback Queue',
                onPressed: () {
                  QueueBottomSheet.show(context);
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  double currentRate = 1.0;
                  if (state is PlayerPlaying) {
                    currentRate = state.playbackRate;
                  } else if (state is PlayerPaused) {
                    currentRate = state.playbackRate;
                  }
                  _showSpeedDialog(context, currentRate);
                },
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
                      child: AlbumArtWidget(
                        albumArt: currentSong.albumArt,
                        width: 280,
                        height: 280,
                        isCircular: true,
                        fallbackIcon: Icons.disc_full_rounded,
                        iconSize: 140,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Song Info with Heart (Favorite) Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSong.title,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${currentSong.artist} • ${currentSong.album}',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final libState = context.watch<LibraryBloc>().state;
                        bool isFavorite = false;
                        if (libState is LibraryLoaded) {
                          final favIndex = libState.playlists.indexWhere((p) => p.name.toLowerCase() == 'favorites');
                          if (favIndex != -1) {
                            isFavorite = libState.playlists[favIndex].songs.any((s) => s.id == currentSong.id);
                          }
                        }

                        return IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFavorite ? Colors.redAccent : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          iconSize: 28,
                          onPressed: () {
                            context.read<LibraryBloc>().add(ToggleFavoriteEvent(currentSong));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isFavorite
                                      ? 'Removed from Favorites'
                                      : 'Added to Favorites',
                                  style: GoogleFonts.outfit(),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Progress Slider with Live Sine Wave Track & Timers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        final showWave = getIt<SettingsService>().showPlayerWaveform;
                        return SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackShape: SineWaveSliderTrackShape(
                              waveAnimationValue: _waveController.value,
                              isPlaying: isPlaying && showWave,
                            ),
                            activeTrackColor: theme.colorScheme.primary,
                            inactiveTrackColor: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                            thumbColor: theme.colorScheme.primary,
                          ),
                          child: Slider(
                            min: 0,
                            max: sliderMax,
                            value: sliderValue,
                            onChangeStart: (value) {
                              setState(() {
                                _isDragging = true;
                                _dragPosition = value;
                              });
                            },
                            onChanged: (value) {
                              setState(() {
                                _dragPosition = value;
                              });
                            },
                            onChangeEnd: (value) {
                              setState(() {
                                _isDragging = false;
                              });
                              context.read<PlayerBloc>().add(
                                    SeekEvent(Duration(milliseconds: value.toInt())),
                                  );
                            },
                          ),
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
                      child: isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                            )
                          : IconButton(
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
                        repeatMode == 'One'
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: repeatMode != 'Off'
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      tooltip: 'Repeat Mode: $repeatMode',
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

  void _showSpeedDialog(BuildContext context, double currentRate) {
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
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((rate) {
                  final isSelected = (rate - currentRate).abs() < 0.01;
                  return ChoiceChip(
                    label: Text('${rate}x'),
                    selected: isSelected,
                    onSelected: (selected) {
                      context
                          .read<PlayerBloc>()
                          .add(SetPlaybackRateEvent(rate));
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.bedtime_rounded),
                title: Text('Sleep Timer', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  SleepTimerDialog.show(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class SineWaveSliderTrackShape extends RoundedRectSliderTrackShape {
  final double waveAnimationValue;
  final bool isPlaying;

  SineWaveSliderTrackShape({
    required this.waveAnimationValue,
    required this.isPlaying,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = true,
    bool isDiscrete = false,
    required TextDirection textDirection,
    double additionalActiveTrackHeight = 0,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Canvas canvas = context.canvas;
    final activeColor = sliderTheme.activeTrackColor ?? Colors.purpleAccent;
    final inactiveColor = sliderTheme.inactiveTrackColor ?? Colors.white24;

    // 1. Inactive track (right side of thumb handle)
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    if (thumbCenter.dx < trackRect.right) {
      canvas.drawLine(
        Offset(thumbCenter.dx, trackRect.center.dy),
        Offset(trackRect.right, trackRect.center.dy),
        inactivePaint,
      );
    }

    // 2. Active track (left side of thumb handle) with animated Sine Wave
    final activeWidth = thumbCenter.dx - trackRect.left;
    if (activeWidth > 0) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isPlaying ? 3.5 : 3.0
        ..strokeCap = StrokeCap.round;

      if (!isPlaying || activeWidth < 12) {
        canvas.drawLine(
          Offset(trackRect.left, trackRect.center.dy),
          Offset(thumbCenter.dx, trackRect.center.dy),
          activePaint,
        );
      } else {
        final path = Path();
        path.moveTo(trackRect.left, trackRect.center.dy);

        final double amplitude = 5.5;
        final double frequency = 0.08;
        final double phase = waveAnimationValue * 2 * math.pi;

        for (double x = trackRect.left; x <= thumbCenter.dx; x += 1.5) {
          final relativeX = x - trackRect.left;
          final double edgeFade =
              math.sin(math.pi * (relativeX / activeWidth)).clamp(0.0, 1.0);
          final double y = trackRect.center.dy +
              (math.sin((relativeX * frequency) - phase) * amplitude * edgeFade);
          path.lineTo(x, y);
        }

        canvas.drawPath(path, activePaint);
      }
    }
  }
}
