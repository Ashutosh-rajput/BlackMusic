import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/core/utils/duration_formatter.dart';
import 'package:pixel_player/data/models/jiosaavn_item.dart';
import 'package:pixel_player/core/utils/jiosaavn_decoder.dart';
import 'package:pixel_player/data/models/youtube_video_item.dart';
import 'package:pixel_player/services/download_service.dart';
import 'package:pixel_player/presentation/widgets/download_queue_snackbar.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

// ─── Public API ───────────────────────────────────────────────────────────────

class DownloadQueueSheet extends StatefulWidget {
  const DownloadQueueSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const DownloadQueueSheet(),
      ),
    );
  }

  @override
  State<DownloadQueueSheet> createState() => _DownloadQueueSheetState();
}

// ─── State ────────────────────────────────────────────────────────────────────

class _DownloadQueueSheetState extends State<DownloadQueueSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A26) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.cloud_download_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Download Center',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Queue action buttons
                ValueListenableBuilder<List<ActiveDownload>>(
                  valueListenable:
                      getIt<DownloadService>().downloadQueueNotifier,
                  builder: (context, queue, _) {
                    final hasActive = queue.any((d) =>
                        d.status == DownloadStatus.queued ||
                        d.status == DownloadStatus.downloading);
                    final hasFinished = queue.any(
                        (d) => d.isCompleted || d.isCancelled || d.isFailed);
                    if (!hasActive && !hasFinished) {
                      return const SizedBox.shrink();
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasActive)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () =>
                                getIt<DownloadService>().cancelAllDownloads(),
                            icon: const Icon(Icons.cancel_outlined,
                                size: 14, color: Colors.redAccent),
                            label: Text('Cancel',
                                style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.redAccent)),
                          ),
                        if (hasActive && hasFinished) const SizedBox(width: 4),
                        if (hasFinished)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => getIt<DownloadService>()
                                .clearCompletedDownloads(),
                            icon: Icon(Icons.cleaning_services_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant),
                            label: Text('Clear',
                                style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF262634)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: theme.colorScheme.onSurface
                    .withValues(alpha: 0.6),
                labelStyle: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle:
                    GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14),
                tabs: const [
                  Tab(
                    icon: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.downloading_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Queue'),
                      ],
                    ),
                  ),
                  Tab(
                    icon: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Search'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _QueueTab(),
                _SearchTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Queue Tab ────────────────────────────────────────────────────────────────

class _QueueTab extends StatefulWidget {
  const _QueueTab();

  @override
  State<_QueueTab> createState() => _QueueTabState();
}

class _QueueTabState extends State<_QueueTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _urlController = TextEditingController();
  final DownloadService _downloadService = getIt<DownloadService>();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _addLinkToQueue() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      _downloadService.enqueueDownload(url: url);
      _urlController.clear();
      if (mounted) {
        showDownloadQueuedSnackBar(context, title: 'Link added to queue');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // URL input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  onSubmitted: (_) => _addLinkToQueue(),
                  decoration: InputDecoration(
                    hintText: 'Paste YouTube / MP3 / JioSaavn link...',
                    prefixIcon: const Icon(Icons.link_rounded),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF262634)
                        : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Add', style: GoogleFonts.outfit()),
                onPressed: _addLinkToQueue,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),

        // Queue list
        Expanded(
          child: ValueListenableBuilder<List<ActiveDownload>>(
            valueListenable: _downloadService.downloadQueueNotifier,
            builder: (context, queue, _) {
              if (queue.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded,
                          size: 56,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.25)),
                      const SizedBox(height: 14),
                      Text(
                        'No downloads in queue',
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Paste a link above or search for music',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: queue.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _QueueItemTile(item: queue[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Search Tab ───────────────────────────────────────────────────────────────

class _SearchTab extends StatefulWidget {
  const _SearchTab();

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  static String _cachedQuery = '';
  static List<YouTubeVideoItem> _cachedYoutubeResults = [];
  static List<JioSaavnItem> _cachedSaavnSongResults = [];
  static List<JioSaavnItem> _cachedSaavnAlbumResults = [];

  bool _isSearching = false;
  List<YouTubeVideoItem> _youtubeResults = [];
  List<JioSaavnItem> _saavnSongResults = [];
  List<JioSaavnItem> _saavnAlbumResults = [];

  String _lastQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (_cachedQuery.isNotEmpty) {
      _searchController.text = _cachedQuery;
      _youtubeResults = List.from(_cachedYoutubeResults);
      _saavnSongResults = List.from(_cachedSaavnSongResults);
      _saavnAlbumResults = List.from(_cachedSaavnAlbumResults);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    if (q.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _youtubeResults = [];
        _saavnSongResults = [];
        _saavnAlbumResults = [];
        _cachedQuery = '';
        _cachedYoutubeResults = [];
        _cachedSaavnSongResults = [];
        _cachedSaavnAlbumResults = [];
      });
    } else {
      setState(() {});
    }
  }

  void _submitSearch(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    _doSearch(query);
  }

  Future<void> _doSearch(String q) async {
    _lastQuery = q;
    const jiosaavnBase = 'https://jiosaavn-api-eight-beryl.vercel.app';
    final dio = Dio();

    try {
      final results = await Future.wait([
        // YouTube
        () async {
          try {
            final youtube = yt.YoutubeExplode();
            final list = await youtube.search.search(q);
            final items = list.take(8).map((v) => YouTubeVideoItem(
                  id: v.id.value,
                  title: v.title,
                  author: v.author,
                  duration: v.duration ?? Duration.zero,
                  thumbnailUrl: v.thumbnails.mediumResUrl,
                  url: v.url,
                )).toList();
            youtube.close();
            return items;
          } catch (_) {
            return <YouTubeVideoItem>[];
          }
        }(),

        // JioSaavn songs
        () async {
          try {
            final resp = await dio.get(
              '$jiosaavnBase/api/songs',
              queryParameters: {'q': q},
              options: Options(
                receiveTimeout: const Duration(seconds: 8),
                sendTimeout: const Duration(seconds: 8),
              ),
            );
            final data = resp.data;
            if (data is Map && data['results'] is List) {
              return (data['results'] as List)
                  .take(6)
                  .map((j) => JioSaavnItem.fromSongJson(
                      Map<String, dynamic>.from(j as Map)))
                  .toList();
            }
          } catch (_) {}
          return <JioSaavnItem>[];
        }(),

        // JioSaavn albums
        () async {
          try {
            final resp = await dio.get(
              '$jiosaavnBase/api/albums',
              queryParameters: {'q': q},
              options: Options(
                receiveTimeout: const Duration(seconds: 8),
                sendTimeout: const Duration(seconds: 8),
              ),
            );
            final data = resp.data;
            if (data is Map && data['results'] is List) {
              return (data['results'] as List)
                  .take(4)
                  .map((j) => JioSaavnItem.fromAlbumJson(
                      Map<String, dynamic>.from(j as Map)))
                  .toList();
            }
          } catch (_) {}
          return <JioSaavnItem>[];
        }(),
      ]);
      dio.close();

      if (!mounted || _lastQuery != q) return;
      setState(() {
        _isSearching = false;
        _youtubeResults = results[0] as List<YouTubeVideoItem>;
        _saavnSongResults = results[1] as List<JioSaavnItem>;
        _saavnAlbumResults = results[2] as List<JioSaavnItem>;
        _cachedQuery = q;
        _cachedYoutubeResults = _youtubeResults;
        _cachedSaavnSongResults = _saavnSongResults;
        _cachedSaavnAlbumResults = _saavnAlbumResults;
      });
    } catch (_) {
      dio.close();
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
            onSubmitted: _submitSearch,
            decoration: InputDecoration(
              hintText: 'Search songs, albums on YouTube & JioSaavn...',
              prefixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search_rounded),
                      tooltip: 'Search',
                      onPressed: () => _submitSearch(_searchController.text),
                    ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF262634) : Colors.grey.shade100,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _searchController.text.isEmpty
              ? _buildEmptySearchPrompt(theme)
              : _buildSearchResults(theme),
        ),
      ],
    );
  }

  Widget _buildEmptySearchPrompt(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.manage_search_rounded,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Search for music to download',
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SourceBadge(label: '🎶 JioSaavn', color: const Color(0xFFFF6B35)),
              const SizedBox(width: 8),
              _SourceBadge(label: '▶ YouTube', color: Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    final hasAny = _youtubeResults.isNotEmpty ||
        _saavnSongResults.isNotEmpty ||
        _saavnAlbumResults.isNotEmpty;

    if (!_isSearching && !hasAny) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 52,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No results found',
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.45)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        // JioSaavn Songs
        if (_saavnSongResults.isNotEmpty) ...[
          _SectionHeader(
            label: 'JioSaavn Songs',
            badge: '${_saavnSongResults.length} • 320 kbps HQ',
            color: const Color(0xFFFF6B35),
          ),
          ..._saavnSongResults
              .map((item) => _InlineJioSaavnTile(item: item)),
          const SizedBox(height: 8),
        ],
        // JioSaavn Albums
        if (_saavnAlbumResults.isNotEmpty) ...[
          _SectionHeader(
            label: 'JioSaavn Albums',
            badge: '${_saavnAlbumResults.length} • 320 kbps',
            color: const Color(0xFFFF6B35),
          ),
          ..._saavnAlbumResults
              .map((item) => _InlineJioSaavnTile(item: item)),
          const SizedBox(height: 8),
        ],
        // YouTube
        if (_youtubeResults.isNotEmpty) ...[
          _SectionHeader(
            label: 'YouTube',
            badge: '${_youtubeResults.length} • 128 kbps',
            color: Colors.red,
          ),
          ..._youtubeResults.map((item) => _InlineYoutubeTile(item: item)),
        ],
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SourceBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String badge;
  final Color color;
  const _SectionHeader(
      {required this.label, required this.badge, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            badge,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineJioSaavnTile extends StatefulWidget {
  final JioSaavnItem item;
  const _InlineJioSaavnTile({required this.item});

  @override
  State<_InlineJioSaavnTile> createState() => _InlineJioSaavnTileState();
}

class _InlineJioSaavnTileState extends State<_InlineJioSaavnTile> {
  bool _isExpanded = false;
  bool _isLoading = false;
  bool _loadFailed = false;
  List<JioSaavnItem> _tracks = [];

  void _toggleExpand() async {
    if (!widget.item.isAlbum && !widget.item.isPlaylist) return;
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded && _tracks.isEmpty && !_isLoading) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
      final token = widget.item.token.isNotEmpty ? widget.item.token : widget.item.id;
      final list = widget.item.isAlbum
          ? await JioSaavnDecoder.fetchAlbumSongs(token)
          : await JioSaavnDecoder.fetchPlaylistSongs(token);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _tracks = list;
        _loadFailed = list.isEmpty;
      });
    }
  }

  void _downloadWholeAlbum() {
    final downloadService = getIt<DownloadService>();
    final token = widget.item.token.isNotEmpty ? widget.item.token : widget.item.id;
    final url = widget.item.isAlbum
        ? 'jiosaavn-album:$token'
        : 'jiosaavn-playlist:$token';
    downloadService.enqueueDownload(
      url: url,
      title: widget.item.title,
      artist: widget.item.subtitle,
      album: widget.item.title,
      albumArt: widget.item.imageUrl,
    );
    if (context.mounted) {
      showDownloadQueuedSnackBar(context, title: widget.item.title);
    }
  }

  void _downloadTrack(JioSaavnItem track) {
    final downloadService = getIt<DownloadService>();
    final directUrl = track.directMediaUrl ?? JioSaavnDecoder.decryptMediaUrl(track.encryptedMediaUrl);
    if (directUrl != null) {
      final secs = int.tryParse(track.duration ?? '0') ?? 0;
      downloadService.enqueueDownload(
        url: directUrl,
        title: track.title,
        artist: track.subtitle,
        album: widget.item.isAlbum ? widget.item.title : track.subtitle,
        albumArt: track.imageUrl.isNotEmpty ? track.imageUrl : widget.item.imageUrl,
        duration: secs > 0 ? Duration(seconds: secs) : null,
      );
      if (context.mounted) {
        showDownloadQueuedSnackBar(context, title: track.title);
      }
    }
  }

  void _downloadSingleSong() {
    final downloadService = getIt<DownloadService>();
    final directUrl = widget.item.directMediaUrl ?? JioSaavnDecoder.decryptMediaUrl(widget.item.encryptedMediaUrl);
    final url = directUrl ?? (widget.item.encryptedMediaUrl != null
        ? 'jiosaavn:${widget.item.encryptedMediaUrl}'
        : 'jiosaavn-token:${widget.item.token.isNotEmpty ? widget.item.token : widget.item.id}');
    final secs = int.tryParse(widget.item.duration ?? '0') ?? 0;
    downloadService.enqueueDownload(
      url: url,
      title: widget.item.title,
      artist: widget.item.subtitle,
      album: widget.item.subtitle.isNotEmpty ? widget.item.subtitle : 'JioSaavn',
      albumArt: widget.item.imageUrl,
      duration: secs > 0 ? Duration(seconds: secs) : null,
    );
    if (context.mounted) {
      showDownloadQueuedSnackBar(context, title: widget.item.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = getIt<DownloadService>();
    final theme = Theme.of(context);
    final isExpandable = widget.item.isAlbum || widget.item.isPlaylist;

    String subtitleText = widget.item.subtitle;
    if (widget.item.isSong && widget.item.duration != null) {
      final secs = int.tryParse(widget.item.duration ?? '0') ?? 0;
      subtitleText += ' • ${formatDuration(Duration(seconds: secs))}';
    } else if (isExpandable && widget.item.songCount != null) {
      subtitleText = '${widget.item.songCount} songs';
    }

    Widget trailingWidget;
    if (isExpandable) {
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            icon: const Icon(Icons.download_rounded, size: 18),
            tooltip: 'Download All',
            onPressed: _downloadWholeAlbum,
          ),
          IconButton(
            icon: Icon(
              _isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 22,
            ),
            tooltip: _isExpanded ? 'Collapse' : 'Expand album',
            onPressed: _toggleExpand,
          ),
        ],
      );
    } else {
      trailingWidget = ValueListenableBuilder<List<ActiveDownload>>(
        valueListenable: downloadService.downloadQueueNotifier,
        builder: (context, queue, _) {
          final directUrl = widget.item.directMediaUrl ??
              JioSaavnDecoder.decryptMediaUrl(widget.item.encryptedMediaUrl);
          final active = queue.where((d) =>
              (directUrl != null && d.url == directUrl) ||
              (widget.item.encryptedMediaUrl != null &&
                  (d.url == widget.item.encryptedMediaUrl ||
                      d.url == 'jiosaavn:${widget.item.encryptedMediaUrl}')) ||
              d.id == widget.item.id).isNotEmpty
              ? queue.lastWhere((d) =>
                  (directUrl != null && d.url == directUrl) ||
                  (widget.item.encryptedMediaUrl != null &&
                      (d.url == widget.item.encryptedMediaUrl ||
                          d.url == 'jiosaavn:${widget.item.encryptedMediaUrl}')) ||
                  d.id == widget.item.id)
              : null;

          if (active == null) {
            return IconButton.filledTonal(
              icon: const Icon(Icons.download_rounded, size: 20),
              onPressed: _downloadSingleSong,
              tooltip: 'Download',
            );
          } else if (active.isCompleted) {
            return const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 24);
          } else if (active.isDownloading) {
            return SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                value: active.progress > 0 ? active.progress : null,
                strokeWidth: 3,
              ),
            );
          } else if (active.isQueued) {
            return const Icon(Icons.schedule_rounded,
                color: Colors.orange, size: 24);
          } else {
            return IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.red, size: 20),
              onPressed: _downloadSingleSong,
            );
          }
        },
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.item.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.item.imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: theme.colorScheme.primaryContainer,
                        child: Icon(
                            isExpandable
                                ? Icons.album_rounded
                                : Icons.music_note_rounded,
                            color: theme.colorScheme.onPrimaryContainer),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: theme.colorScheme.primaryContainer,
                      child: Icon(
                          isExpandable
                              ? Icons.album_rounded
                              : Icons.music_note_rounded,
                          color: theme.colorScheme.onPrimaryContainer),
                    ),
            ),
            title: Text(
              widget.item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.item.type.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.item.quality,
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00C853),
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
            trailing: trailingWidget,
            onTap: isExpandable ? _toggleExpand : _downloadSingleSong,
          ),
          if (isExpandable && _isExpanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading tracks...',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              )
            else if (_loadFailed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text('Failed to load songs. Tap to retry',
                      style: GoogleFonts.outfit(fontSize: 12)),
                  onPressed: () {
                    setState(() => _tracks = []);
                    _toggleExpand();
                  },
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
                child: Row(
                  children: [
                    Text(
                      '${_tracks.length} Songs in ${widget.item.isAlbum ? 'Album' : 'Playlist'}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: Text('Download All',
                          style: GoogleFonts.outfit(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _downloadWholeAlbum,
                    ),
                  ],
                ),
              ),
              ...List.generate(_tracks.length, (index) {
                final track = _tracks[index];
                final secs = int.tryParse(track.duration ?? '0') ?? 0;
                final dur =
                    secs > 0 ? formatDuration(Duration(seconds: secs)) : '';
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  leading: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          track.quality,
                          style: GoogleFonts.outfit(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00C853),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${track.subtitle}${dur.isNotEmpty ? ' • $dur' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  trailing: ValueListenableBuilder<List<ActiveDownload>>(
                    valueListenable: downloadService.downloadQueueNotifier,
                    builder: (context, queue, _) {
                      final directUrl = track.directMediaUrl ??
                          JioSaavnDecoder.decryptMediaUrl(
                              track.encryptedMediaUrl);
                      final active = queue.where((d) =>
                          (directUrl != null && d.url == directUrl) ||
                          (track.encryptedMediaUrl != null &&
                              (d.url == track.encryptedMediaUrl ||
                                  d.url ==
                                      'jiosaavn:${track.encryptedMediaUrl}')) ||
                          d.id == track.id).isNotEmpty
                          ? queue.lastWhere((d) =>
                              (directUrl != null && d.url == directUrl) ||
                              (track.encryptedMediaUrl != null &&
                                  (d.url == track.encryptedMediaUrl ||
                                      d.url ==
                                          'jiosaavn:${track.encryptedMediaUrl}')) ||
                              d.id == track.id)
                          : null;

                      if (active == null) {
                        return IconButton(
                          icon: const Icon(Icons.download_rounded, size: 18),
                          tooltip: 'Download song',
                          onPressed: () => _downloadTrack(track),
                        );
                      } else if (active.isCompleted) {
                        return const Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 20);
                      } else if (active.isDownloading) {
                        return SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            value: active.progress > 0 ? active.progress : null,
                            strokeWidth: 2.5,
                          ),
                        );
                      } else if (active.isQueued) {
                        return const Icon(Icons.schedule_rounded,
                            color: Colors.orange, size: 20);
                      } else {
                        return IconButton(
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.red, size: 18),
                          onPressed: () => _downloadTrack(track),
                        );
                      }
                    },
                  ),
                  onTap: () => _downloadTrack(track),
                );
              }),
              const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }
}

class _InlineYoutubeTile extends StatelessWidget {
  final YouTubeVideoItem item;
  const _InlineYoutubeTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final downloadService = getIt<DownloadService>();
    final theme = Theme.of(context);

    void onDownload() {
      downloadService.enqueueDownload(
        url: item.url,
        title: item.title,
        artist: item.author,
        albumArt: item.thumbnailUrl,
        duration: item.duration,
      );
      if (context.mounted) {
        showDownloadQueuedSnackBar(context, title: item.title);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: item.thumbnailUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: 48,
              height: 48,
              color: theme.colorScheme.primaryContainer,
              child: const Icon(Icons.play_circle_outline_rounded),
            ),
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
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.quality,
                style: GoogleFonts.outfit(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${item.author} • ${formatDuration(item.duration)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: ValueListenableBuilder<List<ActiveDownload>>(
          valueListenable: downloadService.downloadQueueNotifier,
          builder: (context, queue, _) {
            final active = downloadService.getDownloadByUrl(item.url);

            if (active == null) {
              return IconButton.filledTonal(
                icon: const Icon(Icons.download_rounded, size: 20),
                onPressed: onDownload,
                tooltip: 'Download',
              );
            } else if (active.isCompleted) {
              return const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 24);
            } else if (active.isDownloading) {
              return SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  value: active.progress > 0 ? active.progress : null,
                  strokeWidth: 3,
                ),
              );
            } else if (active.isQueued) {
              return const Icon(Icons.schedule_rounded,
                  color: Colors.orange, size: 24);
            } else {
              return IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.red, size: 20),
                onPressed: onDownload,
              );
            }
          },
        ),
        onTap: onDownload,
      ),
    );
  }
}

// ─── Queue item tile ──────────────────────────────────────────────────────────

class _QueueItemTile extends StatelessWidget {
  final ActiveDownload item;

  const _QueueItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget statusIcon;
    Color statusColor;

    if (item.pendingLibraryAcceptance) {
      statusIcon = const Icon(Icons.download_done_rounded,
          color: Colors.amber, size: 24);
      statusColor = Colors.amber.shade800;
    } else if (item.isCompleted) {
      statusIcon = const Icon(Icons.check_circle_rounded,
          color: Colors.green, size: 24);
      statusColor = Colors.green;
    } else if (item.isDownloading) {
      statusIcon = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
      statusColor = theme.colorScheme.primary;
    } else if (item.isQueued) {
      statusIcon =
          const Icon(Icons.schedule_rounded, color: Colors.orange, size: 24);
      statusColor = Colors.orange;
    } else if (item.isFailed) {
      statusIcon =
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24);
      statusColor = Colors.red;
    } else {
      statusIcon =
          const Icon(Icons.cancel_outlined, color: Colors.grey, size: 24);
      statusColor = Colors.grey;
    }

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF262634) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (item.albumArt != null && item.albumArt!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: item.albumArt!,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => statusIcon,
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  statusIcon,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        item.artist != null && item.artist!.isNotEmpty
                            ? '${item.artist} • ${item.statusMessage}'
                            : item.statusMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: statusColor),
                      ),
                    ],
                  ),
                ),
                if (item.pendingLibraryAcceptance) ...[
                  IconButton(
                    icon: const Icon(Icons.playlist_add_check_rounded, size: 22),
                    color: Colors.green,
                    tooltip: 'Add to Library',
                    onPressed: () =>
                        getIt<DownloadService>().acceptSharedDownload(item.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    tooltip: 'Discard',
                    onPressed: () =>
                        getIt<DownloadService>().discardSharedDownload(item.id),
                  ),
                ] else if (item.isDownloading || item.isQueued)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Cancel',
                    onPressed: () => getIt<DownloadService>()
                        .cancelDownloadByUrl(item.url),
                  )
                else if (item.isFailed || item.isCancelled)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Retry Download',
                    onPressed: () => getIt<DownloadService>().enqueueDownload(
                      url: item.url,
                      title: item.title,
                    ),
                  ),
              ],
            ),
            if (item.isDownloading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progress > 0 ? item.progress : null,
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
