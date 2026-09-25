import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/data/models/lyrics_model.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/services/audio_service.dart';
import 'package:pixel_player/services/lyrics_service.dart';

class LyricsView extends StatefulWidget {
  final Song song;
  final VoidCallback? onClose;

  const LyricsView({
    required this.song,
    this.onClose,
    super.key,
  });

  /// Static helper to open the search modal from anywhere (e.g. PlayerScreen three-dot menu)
  static Future<void> showSearchModal(
    BuildContext context,
    Song song, {
    void Function(LyricsData)? onLyricsSaved,
  }) async {
    final lyricsService = getIt<LyricsService>();
    final searchController = TextEditingController(
      text: LyricsService.cleanQuery(song.title),
    );
    List<LyricSearchResultItem> searchResults = [];
    bool isSearching = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);

            void doSearch() async {
              final query = searchController.text.trim();
              if (query.isEmpty) return;
              setSheetState(() => isSearching = true);
              final results = await lyricsService.searchLyrics(query);
              setSheetState(() {
                searchResults = results;
                isSearching = false;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Search Lyrics',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Track name or artist...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => doSearch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: doSearch,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isSearching)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (searchResults.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            'Enter song or artist name to find lyrics',
                            style: GoogleFonts.outfit(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final res = searchResults[index];
                            final isWord = res.isWordSynced;
                            final isLine = res.isLineSynced;
                            final isInst = res.instrumental;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      res.trackName,
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isWord)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome_rounded, size: 10, color: theme.colorScheme.primary),
                                          const SizedBox(width: 2),
                                          Text(
                                            'WORD SYNCED',
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (isLine)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'SYNCED',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.greenAccent.shade700,
                                        ),
                                      ),
                                    )
                                  else if (isInst)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'INSTRUMENTAL',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                '${res.artistName} • ${res.albumName.isNotEmpty ? res.albumName : (res.source == 'binimum' ? 'Apple Music' : 'LRCLIB')}',
                                style: GoogleFonts.outfit(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Chip(
                                label: Text(
                                  res.source == 'binimum' ? 'Apple Music' : 'LRCLIB',
                                  style: GoogleFonts.outfit(fontSize: 10),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onTap: () async {
                                final messenger = ScaffoldMessenger.maybeOf(context);
                                Navigator.pop(ctx);
                                final lyrics = await lyricsService.saveSearchResult(
                                  song.id,
                                  res,
                                );
                                onLyricsSaved?.call(lyrics);
                                messenger?.showSnackBar(
                                  SnackBar(
                                    content: Text('Lyrics saved!', style: GoogleFonts.outfit()),
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
              ),
            );
          },
        );
      },
    );
  }

  @override
  State<LyricsView> createState() => LyricsViewState();
}

class LyricsViewState extends State<LyricsView> {
  final LyricsService _lyricsService = getIt<LyricsService>();
  final AudioPlayerService _audioService = getIt<AudioPlayerService>();

  LyricsData? _lyricsData;
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription<Duration>? _positionSub;
  Timer? _smoothUpdateTimer;
  final ScrollController _scrollController = ScrollController();

  Duration _currentPosition = Duration.zero;
  int _currentIndex = -1;
  bool _userIsScrolling = false;
  Timer? _userScrollDebounce;

  final Map<int, GlobalKey> _lineKeys = {};

  @override
  void initState() {
    super.initState();
    _loadLyrics();
    _subscribeToPosition();
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _currentIndex = -1;
      _lineKeys.clear();
      _loadLyrics();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _smoothUpdateTimer?.cancel();
    _userScrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> reloadLyrics() => _loadLyrics(forceRefresh: true);

  Future<void> _loadLyrics({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lyrics = await _lyricsService.getLyrics(widget.song, forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _lyricsData = lyrics;
          _isLoading = false;
        });
        _updateTickerState();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load lyrics: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _updateTickerState() {
    _smoothUpdateTimer?.cancel();
    if (_lyricsData != null && _lyricsData!.isWordSynced) {
      _smoothUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        if (_audioService.isPlaying) {
          final pos = _audioService.player.position;
          if ((pos - _currentPosition).inMilliseconds.abs() > 60) {
            setState(() {
              _currentPosition = pos;
            });
          }
        }
      });
    }
  }

  void _subscribeToPosition() {
    _positionSub = _audioService.positionStream.listen((position) {
      if (!mounted) return;

      _currentPosition = position;

      if (_lyricsData == null || !_lyricsData!.isSynced) return;

      final newIndex = _lyricsData!.findActiveIndex(position);
      if (newIndex != _currentIndex) {
        setState(() {
          _currentIndex = newIndex;
        });

        if (!_userIsScrolling && newIndex >= 0) {
          _scrollToIndex(newIndex);
        }
      } else if (_lyricsData!.isWordSynced && _currentIndex >= 0) {
        setState(() {});
      }
    });
  }

  void _scrollToIndex(int index) {
    final key = _lineKeys[index];
    if (key == null || key.currentContext == null) {
      if (_scrollController.hasClients) {
        final targetOffset = (index * 72.0) - 180;
        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.38,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _onUserScrolled() {
    _userIsScrolling = true;
    _userScrollDebounce?.cancel();
    _userScrollDebounce = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _userIsScrolling = false;
        if (_currentIndex >= 0) {
          _scrollToIndex(_currentIndex);
        }
      }
    });
  }

  void _seekToPosition(Duration position) {
    if (position < Duration.zero) return;
    context.read<PlayerBloc>().add(SeekEvent(position));
  }

  void _copyLyricsToClipboard() {
    if (_lyricsData == null || _lyricsData!.isEmpty) return;
    final text = _lyricsData!.plainLyrics ??
        _lyricsData!.lines.map((l) => l.text).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lyrics copied to clipboard', style: GoogleFonts.outfit()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openSearchDialog() {
    LyricsView.showSearchModal(
      context,
      widget.song,
      onLyricsSaved: (saved) {
        if (mounted) {
          setState(() {
            _lyricsData = saved;
            _currentIndex = -1;
          });
          _updateTickerState();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Finding lyrics...',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadLyrics(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_lyricsData == null || _lyricsData!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No Lyrics Found',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We searched Apple Music and LRCLIB but found no match.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _loadLyrics(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text('Retry', style: GoogleFonts.outfit()),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _openSearchDialog,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text('Search Manually', style: GoogleFonts.outfit()),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_lyricsData!.isInstrumental) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
              child: Icon(
                Icons.music_note_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Instrumental Track',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No lyrics for this song',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    // ── Apple Music-style lyrics layout ──────────────────────────────────
    return Column(
      children: [
        // Minimal header row: badge + source + three-dot menu
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
          child: Row(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _lyricsData!.isWordSynced
                      ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.15)
                      : _lyricsData!.isSynced
                          ? Colors.greenAccent.withValues(alpha: isDark ? 0.22 : 0.15)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _lyricsData!.isWordSynced
                          ? Icons.auto_awesome_rounded
                          : _lyricsData!.isSynced
                              ? Icons.sync_rounded
                              : Icons.article_outlined,
                      size: 12,
                      color: _lyricsData!.isWordSynced
                          ? theme.colorScheme.primary
                          : _lyricsData!.isSynced
                              ? Colors.greenAccent.shade700
                              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _lyricsData!.isWordSynced
                          ? 'WORD SYNCED'
                          : _lyricsData!.isSynced
                              ? 'SYNCED'
                              : 'PLAIN',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: _lyricsData!.isWordSynced
                            ? theme.colorScheme.primary
                            : _lyricsData!.isSynced
                                ? Colors.greenAccent.shade700
                                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _lyricsData!.source == 'binimum'
                    ? 'Apple Music'
                    : _lyricsData!.source == 'local_lrc'
                        ? 'Local .lrc'
                        : _lyricsData!.source == 'cache'
                            ? 'Saved'
                            : 'LRCLIB',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                tooltip: 'Lyrics Options',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: EdgeInsets.zero,
                onSelected: (value) async {
                  if (value == 'search') {
                    _openSearchDialog();
                  } else if (value == 'reload') {
                    _loadLyrics(forceRefresh: true);
                  } else if (value == 'copy') {
                    _copyLyricsToClipboard();
                  } else if (value == 'clear') {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    await _lyricsService.deleteCachedLyrics(widget.song.id);
                    _loadLyrics(forceRefresh: true);
                    messenger?.showSnackBar(
                      SnackBar(
                        content: Text('Saved lyrics cleared', style: GoogleFonts.outfit()),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'search',
                    child: Row(children: [
                      const Icon(Icons.search_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text('Search Lyrics', style: GoogleFonts.outfit()),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'reload',
                    child: Row(children: [
                      const Icon(Icons.refresh_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text('Reload Lyrics', style: GoogleFonts.outfit()),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: Row(children: [
                      const Icon(Icons.copy_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text('Copy Lyrics', style: GoogleFonts.outfit()),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(children: [
                      const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Text('Clear Saved', style: GoogleFonts.outfit(color: Colors.redAccent)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Lyrics body
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is UserScrollNotification) _onUserScrolled();
              return false;
            },
            child: _lyricsData!.isSynced
                ? _buildAppleMusicLyrics(theme, isDark)
                : _buildPlainLyricsList(theme),
          ),
        ),
      ],
    );
  }

  // ── Apple Music-style synced lyrics list ─────────────────────────────────
  Widget _buildAppleMusicLyrics(ThemeData theme, bool isDark) {
    final lines = _lyricsData!.lines;
    final isWordSynced = _lyricsData!.isWordSynced;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 24, bottom: 100, left: 20, right: 20),
      itemCount: lines.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final line = lines[index];
        final isActive = index == _currentIndex;
        final isPast = index < _currentIndex;
        final isFuture = index > _currentIndex;

        // Distance from active line (used for progressive dimming)
        final distance = (index - _currentIndex).abs();

        final key = _lineKeys.putIfAbsent(index, () => GlobalKey());

        return GestureDetector(
          key: key,
          onTap: () => _seekToPosition(line.timestamp),
          behavior: HitTestBehavior.opaque,
          child: _AppleMusicLyricLine(
            line: line,
            isActive: isActive,
            isPast: isPast,
            isFuture: isFuture,
            distance: distance,
            isWordSynced: isWordSynced,
            currentPosition: _currentPosition,
            theme: theme,
            isDark: isDark,
            onWordTap: (pos) => _seekToPosition(pos),
          ),
        );
      },
    );
  }

  Widget _buildPlainLyricsList(ThemeData theme) {
    final plainText = _lyricsData!.plainLyrics ?? '';

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 20, bottom: 80, left: 24, right: 24),
      physics: const BouncingScrollPhysics(),
      child: Text(
        plainText,
        style: GoogleFonts.outfit(
          fontSize: 18,
          height: 1.8,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

// ── Single Apple Music-style lyric line ──────────────────────────────────────
class _AppleMusicLyricLine extends StatelessWidget {
  final LyricLine line;
  final bool isActive;
  final bool isPast;
  final bool isFuture;
  final int distance;
  final bool isWordSynced;
  final Duration currentPosition;
  final ThemeData theme;
  final bool isDark;
  final void Function(Duration) onWordTap;

  const _AppleMusicLyricLine({
    required this.line,
    required this.isActive,
    required this.isPast,
    required this.isFuture,
    required this.distance,
    required this.isWordSynced,
    required this.currentPosition,
    required this.theme,
    required this.isDark,
    required this.onWordTap,
  });

  static const double kLyricFontSize = 26.0;

  @override
  Widget build(BuildContext context) {
    // Opacity by distance from active line (Apple Music style depth)
    final double opacity = isActive
        ? 1.0
        : (distance == 1
            ? 0.42
            : (distance == 2 ? 0.28 : 0.16));

    final baseTextColor = isDark ? Colors.white : Colors.black87;
    final topPadding = isActive ? 10.0 : 6.0;
    final bottomPadding = isActive ? 10.0 : 6.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(
        left: 4,
        right: 4,
        top: topPadding,
        bottom: bottomPadding,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        opacity: opacity,
        child: AnimatedScale(
          scale: isActive ? 1.0 : 0.94,
          alignment: Alignment.centerLeft,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Word-synced active line ──
              if (isActive && isWordSynced && line.hasWords)
                _buildWordSyncedLine(kLyricFontSize, baseTextColor)
              else
                // ── Regular line (active plain, or past/future) ──
                Text(
                  line.formattedText.isEmpty ? '♪' : line.formattedText,
                  textAlign: TextAlign.left,
                  style: GoogleFonts.outfit(
                    fontSize: kLyricFontSize,
                    fontWeight: FontWeight.w700,
                    color: baseTextColor,
                    height: 1.38,
                    letterSpacing: 0.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordSyncedLine(double fontSize, Color baseTextColor) {
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      spacing: 7,
      runSpacing: 4,
      children: line.words
          .where((w) => w.text.trim().isNotEmpty)
          .map((word) {
        return _AppleMusicWord(
          word: word,
          currentPosition: currentPosition,
          fontSize: fontSize,
          baseTextColor: baseTextColor,
          theme: theme,
          isDark: isDark,
          onTap: () => onWordTap(word.begin),
        );
      }).toList(),
    );
  }
}

// ── Single word in Apple Music-style ─────────────────────────────────────────
class _AppleMusicWord extends StatelessWidget {
  final LyricWord word;
  final Duration currentPosition;
  final double fontSize;
  final Color baseTextColor;
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onTap;

  const _AppleMusicWord({
    required this.word,
    required this.currentPosition,
    required this.fontSize,
    required this.baseTextColor,
    required this.theme,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cleanText = word.text.trim();
    if (cleanText.isEmpty) return const SizedBox.shrink();

    final totalMs = (word.end - word.begin).inMilliseconds;
    final currentMs = (currentPosition - word.begin).inMilliseconds;

    final bool isSung = currentPosition >= word.end && word.end > Duration.zero;
    final bool isActive = !isSung && currentPosition >= word.begin;

    double progress = 0.0;
    if (isSung) {
      progress = 1.0;
    } else if (isActive && totalMs > 0) {
      progress = (currentMs / totalMs).clamp(0.0, 1.0);
    }

    final Color sungColor = isDark ? Colors.white : Colors.black87;
    final Color unsungColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.32);

    Color wordColor;
    if (isSung) {
      wordColor = sungColor;
    } else if (isActive) {
      wordColor = Color.lerp(unsungColor, sungColor, progress)!;
    } else {
      wordColor = unsungColor;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        cleanText,
        style: GoogleFonts.outfit(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: wordColor,
          height: 1.38,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
