import 'dart:async';
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
import 'package:pixel_player/services/audio_service.dart';
import 'package:pixel_player/services/settings_service.dart';
import 'package:pixel_player/presentation/widgets/album_art_widget.dart';
import 'package:pixel_player/presentation/widgets/queue_bottom_sheet.dart';
import 'package:pixel_player/presentation/widgets/sleep_timer_dialog.dart';
import 'package:pixel_player/presentation/widgets/player_background_pattern.dart';
import 'package:pixel_player/presentation/widgets/lyrics_view.dart';

class PlayerScreen extends StatefulWidget {
  final Song song;

  const PlayerScreen({required this.song, super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _rotationController;
  late AnimationController _waveController;
  StreamSubscription<bool>? _playingSubscription;
  bool _isDragging = false;
  double _dragPosition = 0.0;
  bool _showLyrics = false;
  final GlobalKey<LyricsViewState> _lyricsKey = GlobalKey<LyricsViewState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    final isAudioPlaying = getIt<AudioPlayerService>().isPlaying;
    final playerState = context.read<PlayerBloc>().state;
    if (playerState is PlayerPlaying && isAudioPlaying) {
      _rotationController.repeat();
      _waveController.repeat();
    }

    _playingSubscription = getIt<AudioPlayerService>().playingStream.listen((playing) {
      if (!playing) {
        if (_rotationController.isAnimating) _rotationController.stop();
        if (_waveController.isAnimating) _waveController.stop();
      } else {
        if (mounted && context.read<PlayerBloc>().state is PlayerPlaying) {
          if (!_rotationController.isAnimating) _rotationController.repeat();
          if (!_waveController.isAnimating) _waveController.repeat();
        }
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _playingSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _rotationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _syncAnimation(context.read<PlayerBloc>().state);
    }
  }

  void _syncAnimation(PlayerState state) {
    final shouldAnimate = state is PlayerPlaying && getIt<AudioPlayerService>().isPlaying;
    if (shouldAnimate) {
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
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is PlayerPlaying && current is PlayerPlaying) {
          return previous.song.id != current.song.id ||
              previous.isShuffle != current.isShuffle ||
              previous.isRepeat != current.isRepeat ||
              previous.repeatMode != current.repeatMode ||
              previous.playbackRate != current.playbackRate;
        }
        if (previous is PlayerPaused && current is PlayerPaused) {
          return previous.song.id != current.song.id ||
              previous.isShuffle != current.isShuffle ||
              previous.isRepeat != current.isRepeat ||
              previous.repeatMode != current.repeatMode;
        }
        return true;
      },
      listener: (context, state) => _syncAnimation(state),
      builder: (context, state) {
        Song currentSong = widget.song;
        Duration position = Duration.zero;
        Duration duration = widget.song.duration;
        bool isPlaying = false;
        bool isLoading = false;
        bool isShuffle = false;
        String repeatMode = 'Off';

        final isActuallyPlaying = (state is PlayerPlaying) && getIt<AudioPlayerService>().isPlaying;
        final isActuallyLoading = (state is PlayerLoading) && getIt<AudioPlayerService>().isPlaying;

        if (state is PlayerPlaying) {
          currentSong = state.song;
          position = state.position;
          duration = state.duration.inMilliseconds > 0
              ? state.duration
              : currentSong.duration;
          isPlaying = isActuallyPlaying;
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
          isLoading = isActuallyLoading;
          isPlaying = false;
          isShuffle = state.isShuffle;
          repeatMode = state.repeatMode;
        }

        if (!isPlaying) {
          if (_rotationController.isAnimating) _rotationController.stop();
          if (_waveController.isAnimating) _waveController.stop();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncAnimation(state);
        });

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 32,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'NOW PLAYING',
              style: GoogleFonts.outfit(
                fontSize: 13,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _showLyrics ? Icons.album_rounded : Icons.lyrics_rounded,
                  color: _showLyrics
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white : Colors.black87),
                ),
                tooltip: _showLyrics ? 'Show Album Art' : 'Show Lyrics',
                onPressed: () {
                  setState(() {
                    _showLyrics = !_showLyrics;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.radio_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                tooltip: 'Start Radio',
                onPressed: () {
                  context.read<PlayerBloc>().add(StartRadioEvent(currentSong));
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.queue_music_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                tooltip: 'Playback Queue',
                onPressed: () {
                  QueueBottomSheet.show(context);
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () {
                  double currentRate = 1.0;
                  if (state is PlayerPlaying) {
                    currentRate = state.playbackRate;
                  } else if (state is PlayerPaused) {
                    currentRate = state.playbackRate;
                  }
                  _showPlayerMenu(context, currentRate, currentSong);
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              // Animated background pattern
              Positioned.fill(
                child: PlayerBackgroundPattern(
                  patternIndex: getIt<SettingsService>().playerBackgroundPattern,
                  animation: _waveController,
                  accentColor: theme.colorScheme.primary,
                ),
              ),
              Column(
            children: [
              SizedBox(height: _showLyrics ? 4 : 20),
              // Album Art with Vinyl Spinning Effect or Synced Lyrics
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _showLyrics
                      ? Container(
                          key: const ValueKey('lyrics_view'),
                          child: LyricsView(key: _lyricsKey, song: currentSong),
                        )
                      : GestureDetector(
                          key: const ValueKey('album_art_view'),
                          onTap: () {
                            setState(() {
                              _showLyrics = true;
                            });
                          },
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
                                  fallbackIcon: Icons.music_note_rounded,
                                  iconSize: 130,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
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
                            currentSong.title.isNotEmpty ? currentSong.title : 'Unknown Title',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            currentSong.album.isNotEmpty && currentSong.album != 'Unknown Album'
                                ? '${currentSong.artist} • ${currentSong.album}'
                                : currentSong.artist,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Source & quality badges
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                _SourceBadge(source: currentSong.effectiveSource),
                                if (currentSong.effectiveAudioQuality != null)
                                  _QualityBadge(quality: currentSong.effectiveAudioQuality!),
                              ],
                            ),
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
                            color: isFavorite
                                ? Colors.redAccent
                                : (isDark ? Colors.white70 : Colors.black54),
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
              const SizedBox(height: 8),
              // Progress Slider with Live Sine Wave Track & Timers
              StreamBuilder<Duration>(
                stream: getIt<AudioPlayerService>().positionStream,
                builder: (context, snapshot) {
                  final livePos = snapshot.data ?? position;
                  final currentPos = _isDragging
                      ? Duration(milliseconds: _dragPosition.toInt())
                      : livePos;
                  final liveSliderMax = duration.inMilliseconds.toDouble() > 0
                      ? duration.inMilliseconds.toDouble()
                      : 1.0;
                  final liveSliderValue = currentPos.inMilliseconds.toDouble().clamp(0.0, liveSliderMax);

                  return Padding(
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
                                thumbShape: SnakeHeadSliderThumbShape(
                                  thumbRadius: 11.0,
                                  waveAnimationValue: _waveController.value,
                                  isPlaying: isPlaying && showWave,
                                ),
                                activeTrackColor: theme.colorScheme.primary,
                                inactiveTrackColor: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                                thumbColor: theme.colorScheme.primary,
                              ),
                              child: Slider(
                                min: 0,
                                max: liveSliderMax,
                                value: liveSliderValue,
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
                                formatDuration(currentPos),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              Text(
                                formatDuration(duration),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              // Control Action Buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 22, left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: isShuffle
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.white54 : Colors.black38),
                      ),
                      iconSize: 26,
                      onPressed: () {
                        context.read<PlayerBloc>().add(const ToggleShuffleEvent());
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      iconSize: 38,
                      onPressed: () {
                        context.read<PlayerBloc>().add(const PreviousSongEvent());
                      },
                    ),
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
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
                              iconSize: 34,
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
                      icon: Icon(
                        Icons.skip_next_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      iconSize: 38,
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
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.white54 : Colors.black38),
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
            ], // Stack children
          ), // Stack
        );
      },
    );
  }

  void _showPlayerMenu(BuildContext context, double currentRate, Song currentSong) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Playback Speed',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
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
                  const Divider(height: 28),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.radio_rounded, color: Color(0xFF2BC5B4)),
                    title: Text(
                      'Start Radio',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Queue similar tracks powered by JioSaavn recommendations',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.read<PlayerBloc>().add(StartRadioEvent(currentSong));
                    },
                  ),
                  const Divider(height: 20),

                  // Lyrics Controls in Three-Dot Menu
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_showLyrics ? Icons.album_rounded : Icons.lyrics_rounded),
                    title: Text(
                      _showLyrics ? 'Show Album Art' : 'Show Synced Lyrics',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _showLyrics = !_showLyrics);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.search_rounded),
                    title: Text('Search Lyrics', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!_showLyrics) setState(() => _showLyrics = true);
                      LyricsView.showSearchModal(context, currentSong);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.refresh_rounded),
                    title: Text('Reload Lyrics', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!_showLyrics) setState(() => _showLyrics = true);
                      _lyricsKey.currentState?.reloadLyrics();
                    },
                  ),
                  const Divider(height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
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
            ),
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

class SnakeHeadSliderThumbShape extends SliderComponentShape {
  final double thumbRadius;
  final double waveAnimationValue;
  final bool isPlaying;

  const SnakeHeadSliderThumbShape({
    this.thumbRadius = 11.0,
    required this.waveAnimationValue,
    required this.isPlaying,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final primaryColor = sliderTheme.thumbColor ?? Colors.purpleAccent;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    if (isPlaying) {
      final tilt = math.sin(waveAnimationValue * 2 * math.pi) * 0.12;
      canvas.rotate(tilt);
    }

    // 1. Draw Snake Head Path (pointing forward ->)
    final headPath = Path();
    headPath.moveTo(-thumbRadius * 0.8, -thumbRadius * 0.5);
    headPath.cubicTo(
      -thumbRadius * 0.2,
      -thumbRadius * 0.9,
      thumbRadius * 0.6,
      -thumbRadius * 0.7,
      thumbRadius * 1.2,
      0.0,
    );
    headPath.cubicTo(
      thumbRadius * 0.6,
      thumbRadius * 0.7,
      -thumbRadius * 0.2,
      thumbRadius * 0.9,
      -thumbRadius * 0.8,
      thumbRadius * 0.5,
    );
    headPath.close();

    final headPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(headPath, headPaint);

    // 2. Draw Snake Eyes
    final eyePaint = Paint()
      ..color = isPlaying ? Colors.white : Colors.black87
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(thumbRadius * 0.4, -thumbRadius * 0.3),
      1.8,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(thumbRadius * 0.4, thumbRadius * 0.3),
      1.8,
      eyePaint,
    );

    if (isPlaying) {
      final pupilPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(thumbRadius * 0.45, -thumbRadius * 0.3),
        0.8,
        pupilPaint,
      );
      canvas.drawCircle(
        Offset(thumbRadius * 0.45, thumbRadius * 0.3),
        0.8,
        pupilPaint,
      );

      // Flickering red tongue when playing
      final tonguePhase = math.sin(waveAnimationValue * 4 * math.pi);
      if (tonguePhase > 0.2) {
        final tonguePaint = Paint()
          ..color = Colors.redAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;

        final tonguePath = Path();
        tonguePath.moveTo(thumbRadius * 1.2, 0.0);
        tonguePath.lineTo(thumbRadius * 1.55, 0.0);
        tonguePath.lineTo(thumbRadius * 1.75, -thumbRadius * 0.22);
        tonguePath.moveTo(thumbRadius * 1.55, 0.0);
        tonguePath.lineTo(thumbRadius * 1.75, thumbRadius * 0.22);

        canvas.drawPath(tonguePath, tonguePaint);
      }
    }

    canvas.restore();
  }
}

/// Badge showing song source: YouTube, JioSaavn, or Local
class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (source.toLowerCase()) {
      'youtube' => ('YouTube', const Color(0xFFFF5252), Icons.smart_display_rounded),
      'jiosaavn' => ('JioSaavn', const Color(0xFF26C6DA), Icons.music_note_rounded),
      _ => ('Local', const Color(0xFF90A4AE), Icons.folder_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge showing audio quality
class _QualityBadge extends StatelessWidget {
  final String quality;
  const _QualityBadge({required this.quality});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.high_quality_rounded, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            quality,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
