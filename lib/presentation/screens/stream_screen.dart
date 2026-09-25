import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/core/utils/jiosaavn_decoder.dart';
import 'package:pixel_player/data/models/jiosaavn_item.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/widgets/album_art_widget.dart';
import 'package:pixel_player/presentation/widgets/download_queue_snackbar.dart';
import 'package:pixel_player/services/download_service.dart';
import 'package:pixel_player/services/settings_service.dart';
import 'package:pixel_player/services/stream_cache_service.dart';

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> with AutomaticKeepAliveClientMixin {
  late String _currentLang;
  bool _isLoading = true;
  String? _errorMessage;
  String? _loadingSongId;
  int _selectedFilter = 0; // 0: All, 1: Songs, 2: Albums, 3: Playlists

  // Search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _isSearchLoading = false;
  List<JioSaavnItem> _searchSongs = [];
  List<JioSaavnItem> _searchAlbums = [];

  List<JioSaavnItem> _relatedAlbums = [];
  List<JioSaavnItem> _newReleases = [];
  Map<String, List<JioSaavnItem>> _homeModules = {};
  List<Song> _topPlayed = [];
  List<Song> _lastPlayedStreamSongs = [];
  List<JioSaavnItem> _suggestedSongs = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentLang = getIt<SettingsService>().streamLanguage;
    _loadStreamData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadLastPlayedSongs() async {
    try {
      final history = await getIt<MusicRepository>().getLastPlayedStreamSongs(limit: 50);
      if (mounted) {
        setState(() => _lastPlayedStreamSongs = history);
      }
    } catch (_) {}
  }

  Future<void> _loadStreamData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch top 5 most played songs & last played stream history from repository
      _topPlayed = await getIt<MusicRepository>().getMostPlayedSongs(limit: 5);
      _lastPlayedStreamSongs = await getIt<MusicRepository>().getLastPlayedStreamSongs();

      // 2. Fetch related albums using top played songs
      _relatedAlbums = await _fetchRelatedAlbumsForTopSongs(_topPlayed);

      // 3. Fetch new releases and home feed in parallel
      final results = await Future.wait([
        JioSaavnDecoder.fetchNewReleases(lang: _currentLang),
        JioSaavnDecoder.fetchHomeFeed(lang: _currentLang),
      ]);

      final newReleases = results[0] as List<JioSaavnItem>;
      final homeModules = results[1] as Map<String, List<JioSaavnItem>>;

      List<JioSaavnItem> suggestions = [];
      String? seedId;

      // Priority 1: From home modules
      for (final list in homeModules.values) {
        for (final item in list) {
          if (item.isSong && item.id.isNotEmpty) {
            seedId = item.id;
            break;
          }
        }
        if (seedId != null) break;
      }
      // Priority 2: From new releases
      seedId ??= newReleases.where((i) => i.isSong && i.id.isNotEmpty).firstOrNull?.id;

      // Priority 3: Search popular song for current language as fallback seed
      if (seedId == null || seedId.isEmpty) {
        try {
          final popularSongs = await JioSaavnDecoder.searchSongs(_currentLang);
          seedId = popularSongs.where((s) => s.id.isNotEmpty).firstOrNull?.id;
        } catch (_) {}
      }

      if (seedId != null && seedId.isNotEmpty) {
        suggestions = await JioSaavnDecoder.fetchSongSuggestions(seedId, limit: 10);
      }

      if (!mounted) return;
      setState(() {
        _newReleases = newReleases;
        _homeModules = homeModules;
        _suggestedSongs = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load stream: $e';
      });
    }
  }

  Future<List<JioSaavnItem>> _fetchRelatedAlbumsForTopSongs(List<Song> songs) async {
    final relatedList = <JioSaavnItem>[];
    final seenIds = <String>{};

    for (final song in songs) {
      if (relatedList.length >= 15) break;
      try {
        final query = (song.album.isNotEmpty && song.album != 'Local Music' && song.album != 'Downloads')
            ? song.album
            : song.title;
        final albums = await JioSaavnDecoder.searchAlbums(query);
        if (albums.isNotEmpty) {
          final targetAlbum = albums.first;
          final related = await JioSaavnDecoder.fetchRelatedAlbums(targetAlbum.id);
          for (final item in related) {
            if (!seenIds.contains(item.id)) {
              seenIds.add(item.id);
              relatedList.add(item);
            }
          }
        }
      } catch (_) {}
    }

    return relatedList;
  }

  /// All individual songs aggregated from Trending, New Releases & Home Modules
  List<JioSaavnItem> get _allSongs {
    final list = <JioSaavnItem>[];
    final seen = <String>{};

    // First collect songs from home modules (Trending Now, What's Hot, etc.)
    for (final entry in _homeModules.entries) {
      for (final item in entry.value) {
        if (item.isSong && !seen.contains(item.id)) {
          seen.add(item.id);
          list.add(item);
        }
      }
    }

    // Next collect songs from new releases
    for (final item in _newReleases) {
      if (item.isSong && !seen.contains(item.id)) {
        seen.add(item.id);
        list.add(item);
      }
    }

    // Collect songs from suggestions
    for (final item in _suggestedSongs) {
      if (item.isSong && !seen.contains(item.id)) {
        seen.add(item.id);
        list.add(item);
      }
    }

    return list;
  }

  /// All albums aggregated
  List<JioSaavnItem> get _allAlbums {
    final list = <JioSaavnItem>[];
    final seen = <String>{};

    for (final item in _relatedAlbums) {
      if (!seen.contains(item.id)) {
        seen.add(item.id);
        list.add(item);
      }
    }

    for (final item in _newReleases) {
      if (item.isAlbum && !seen.contains(item.id)) {
        seen.add(item.id);
        list.add(item);
      }
    }

    for (final entry in _homeModules.entries) {
      for (final item in entry.value) {
        if (item.isAlbum && !seen.contains(item.id)) {
          seen.add(item.id);
          list.add(item);
        }
      }
    }

    return list;
  }

  /// All playlists aggregated
  List<JioSaavnItem> get _allPlaylists {
    final list = <JioSaavnItem>[];
    final seen = <String>{};

    for (final entry in _homeModules.entries) {
      for (final item in entry.value) {
        if (item.isPlaylist && !seen.contains(item.id)) {
          seen.add(item.id);
          list.add(item);
        }
      }
    }

    return list;
  }

  void _showLanguageSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final langs = SettingsService.supportedStreamLanguages;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.language_rounded, color: Color(0xFF2BC5B4), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Select Streaming Language',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: langs.entries.map((entry) {
                    final isSelected = entry.key == _currentLang;
                    return ListTile(
                      title: Text(
                        entry.value,
                        style: GoogleFonts.outfit(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF2BC5B4) : null,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2BC5B4))
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (entry.key != _currentLang) {
                          setState(() => _currentLang = entry.key);
                          await getIt<SettingsService>().setStreamLanguage(entry.key);
                          _loadStreamData();
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAlbumDetails(JioSaavnItem album) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF181824)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AlbumTracksSheet(item: album),
    );
  }

  Future<void> _streamSingleSong(JioSaavnItem item) async {
    if (_loadingSongId != null) return;
    setState(() => _loadingSongId = item.id);

    try {
      String? streamUrl = item.directMediaUrl ?? JioSaavnDecoder.decryptMediaUrl(item.encryptedMediaUrl);
      if (streamUrl == null || streamUrl.isEmpty) {
        final details = await JioSaavnDecoder.fetchSongDetails(item.token);
        streamUrl = details?.directMediaUrl ?? JioSaavnDecoder.decryptMediaUrl(details?.encryptedMediaUrl);
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to retrieve stream for "${item.title}"', style: GoogleFonts.outfit()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final song = item.toSong(overrideStreamUrl: streamUrl);
      if (!mounted) return;

      context.read<PlayerBloc>().add(PlaySongEvent(song));
      getIt<MusicRepository>().recordSongPlay(song);
      _loadLastPlayedSongs();

      if (item.id.isNotEmpty) {
        JioSaavnDecoder.fetchSongSuggestions(item.id, limit: 10).then((suggestions) {
          if (mounted && suggestions.isNotEmpty) {
            setState(() => _suggestedSongs = suggestions);
          }
        }).catchError((_) {});
      }

      if (getIt<SettingsService>().autoDownloadStreamSongs) {
        _downloadSong(item, overrideUrl: streamUrl);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Streaming "${song.title}" from JioSaavn', style: GoogleFonts.outfit()),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparing stream: $e', style: GoogleFonts.outfit()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSongId = null);
      }
    }
  }

  Future<void> _downloadSong(JioSaavnItem track, {String? overrideUrl}) async {
    final downloadService = getIt<DownloadService>();
    var directUrl = overrideUrl ?? track.directMediaUrl ?? JioSaavnDecoder.decryptMediaUrl(track.encryptedMediaUrl);
    if (directUrl == null || directUrl.isEmpty) {
      final details = await JioSaavnDecoder.fetchSongDetails(track.token);
      directUrl = details?.directMediaUrl ?? JioSaavnDecoder.decryptMediaUrl(details?.encryptedMediaUrl);
    }
    if (directUrl != null && mounted) {
      final secs = int.tryParse(track.duration ?? '0') ?? 0;
      downloadService.enqueueDownload(
        url: directUrl,
        title: track.title,
        artist: track.subtitle,
        album: track.subtitle.isNotEmpty ? track.subtitle : 'JioSaavn',
        albumArt: track.imageUrl,
        duration: secs > 0 ? Duration(seconds: secs) : null,
      );
      showDownloadQueuedSnackBar(context, title: track.title);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not fetch download link for "${track.title}"', style: GoogleFonts.outfit()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchSongs = [];
        _searchAlbums = [];
        _isSearchLoading = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(query.trim());
    });
  }

  Future<void> _executeSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() => _isSearchLoading = true);

    try {
      final results = await Future.wait([
        JioSaavnDecoder.searchSongs(q),
        JioSaavnDecoder.searchAlbums(q),
      ]);

      if (!mounted) return;
      setState(() {
        _searchSongs = results[0];
        _searchAlbums = results[1];
        _isSearchLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearchLoading = false);
    }
  }

  void _stopSearch() {
    _searchDebounce?.cancel();
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchSongs = [];
      _searchAlbums = [];
      _isSearchLoading = false;
    });
  }

  Widget _buildSearchResults() {
    if (_isSearchLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF2BC5B4)),
            SizedBox(height: 16),
            Text('Searching JioSaavn...'),
          ],
        ),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Search songs and albums on JioSaavn',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchSongs.isEmpty && _searchAlbums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.orange.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No results found for "${_searchController.text.trim()}"',
              style: GoogleFonts.outfit(fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      children: [
        if (_searchSongs.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Songs (${_searchSongs.length})',
            icon: Icons.music_note_rounded,
          ),
          ..._searchSongs.map((song) => _StreamSongTile(
                item: song,
                isLoading: _loadingSongId == song.id,
                onPlay: () => _streamSingleSong(song),
                onDownload: () => _downloadSong(song),
              )),
          const SizedBox(height: 16),
        ],
        if (_searchAlbums.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Albums (${_searchAlbums.length})',
            icon: Icons.album_rounded,
          ),
          _buildHorizontalCardList(_searchAlbums),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final langName = SettingsService.supportedStreamLanguages[_currentLang] ?? _currentLang;
    final allSongs = _allSongs;

    if (_isSearching) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: _stopSearch,
          ),
          title: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            style: GoogleFonts.outfit(fontSize: 16),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search songs, albums on JioSaavn...',
              hintStyle: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
            ),
            onChanged: _onSearchChanged,
            onSubmitted: _executeSearch,
          ),
        ),
        body: _buildSearchResults(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.podcasts_rounded, color: Color(0xFF2BC5B4), size: 24),
            const SizedBox(width: 8),
            Text(
              'Stream',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search JioSaavn',
            onPressed: () => setState(() => _isSearching = true),
          ),
          // Language selector chip in AppBar
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: const Icon(Icons.language_rounded, size: 16, color: Color(0xFF2BC5B4)),
              label: Text(
                langName,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2BC5B4),
                ),
              ),
              backgroundColor: const Color(0xFF2BC5B4).withValues(alpha: 0.15),
              side: const BorderSide(color: Color(0xFF2BC5B4), width: 0.8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: _showLanguageSelector,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _buildFilterChips(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2BC5B4)),
                  SizedBox(height: 16),
                  Text('Loading recommendations...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.orange),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.outfit()),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try Again'),
                          onPressed: _loadStreamData,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF2BC5B4),
                  onRefresh: _loadStreamData,
                  child: _buildBodyContent(langName, allSongs),
                ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Songs', 'Albums', 'Playlists', 'Last Played'];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedFilter == index;
          return ChoiceChip(
            showCheckmark: false,
            label: Text(
              filters[index],
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black : null,
              ),
            ),
            selected: isSelected,
            selectedColor: const Color(0xFF2BC5B4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val) {
                setState(() => _selectedFilter = index);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildBodyContent(String langName, List<JioSaavnItem> allSongs) {
    if (_selectedFilter == 1) {
      // SONGS ONLY VIEW
      return _buildSongsOnlyList(allSongs);
    } else if (_selectedFilter == 2) {
      // ALBUMS ONLY VIEW
      return _buildAlbumsOnlyGrid();
    } else if (_selectedFilter == 3) {
      // PLAYLISTS ONLY VIEW
      return _buildPlaylistsOnlyGrid();
    } else if (_selectedFilter == 4) {
      // LAST PLAYED (HISTORY) VIEW
      return _buildLastPlayedView();
    }

    // ALL (Default overview)
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        // 0. Last Played Stream History (if any)
        if (_lastPlayedStreamSongs.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Last Played',
            subtitle: 'Recently streamed songs',
            icon: Icons.history_rounded,
            actionLabel: _lastPlayedStreamSongs.length > 5 ? 'See All (${_lastPlayedStreamSongs.length})' : null,
            onAction: () => setState(() => _selectedFilter = 4),
          ),
          ..._lastPlayedStreamSongs.take(5).map((song) {
            final item = song.toJioSaavnItem();
            return _StreamSongTile(
              item: item,
              isLoading: _loadingSongId == item.id,
              onPlay: () => _streamSingleSong(item),
              onDownload: () => _downloadSong(item),
            );
          }),
          const SizedBox(height: 16),
        ],

        // 1. Trending Songs (Directly playable single songs)
        if (allSongs.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Trending Songs',
            subtitle: 'Tap to stream instant 320 kbps audio',
            icon: Icons.local_fire_department_rounded,
            actionLabel: allSongs.length > 5 ? 'See All (${allSongs.length})' : null,
            onAction: () => setState(() => _selectedFilter = 1),
          ),
          ...allSongs.take(6).map((item) => _StreamSongTile(
                item: item,
                isLoading: _loadingSongId == item.id,
                onPlay: () => _streamSingleSong(item),
                onDownload: () => _downloadSong(item),
              )),
          const SizedBox(height: 16),
        ],

        // 1.5 Song Suggestions (GET /api/songs/[id]/suggestions?limit=10)
        if (_suggestedSongs.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Song Suggestions',
            subtitle: 'Recommended songs for you',
            icon: Icons.recommend_rounded,
          ),
          ..._suggestedSongs.take(6).map((item) => _StreamSongTile(
                item: item,
                isLoading: _loadingSongId == item.id,
                onPlay: () => _streamSingleSong(item),
                onDownload: () => _downloadSong(item),
              )),
          const SizedBox(height: 16),
        ],

        // 2. Recommended For You (based on top 5 most played songs)
        if (_relatedAlbums.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Recommended For You',
            subtitle: _topPlayed.isNotEmpty
                ? 'Based on your most played tracks'
                : 'Similar to popular albums',
            icon: Icons.auto_awesome_rounded,
          ),
          _buildHorizontalCardList(_relatedAlbums),
          const SizedBox(height: 16),
        ],

        // 3. New Releases (From /api/new)
        if (_newReleases.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'New Releases',
            subtitle: 'Fresh $langName tracks and albums',
            icon: Icons.new_releases_rounded,
          ),
          _buildHorizontalCardList(_newReleases),
          const SizedBox(height: 16),
        ],

        // 4. Home Feed Modules (Top Charts, Editorial Picks, etc.)
        ..._homeModules.entries.where((entry) {
          final normalized = entry.key.trim().toLowerCase().replaceAll('_', ' ');
          return normalized != 'new releases';
        }).map((entry) {
          final title = entry.key.replaceAll('_', ' ').toUpperCase();
          final items = entry.value;
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                title: title,
                icon: Icons.queue_music_rounded,
              ),
              _buildHorizontalCardList(items),
              const SizedBox(height: 16),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildLastPlayedView() {
    if (_lastPlayedStreamSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No stream history yet',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Songs you stream from JioSaavn will appear here',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: _lastPlayedStreamSongs.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (ctx, index) {
        final song = _lastPlayedStreamSongs[index];
        final item = song.toJioSaavnItem();
        return _StreamSongTile(
          item: item,
          isLoading: _loadingSongId == item.id,
          onPlay: () => _streamSingleSong(item),
          onDownload: () => _downloadSong(item),
        );
      },
    );
  }

  Widget _buildSongsOnlyList(List<JioSaavnItem> songs) {
    if (songs.isEmpty) {
      return Center(
        child: Text('No songs found for this language.', style: GoogleFonts.outfit()),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: songs.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (ctx, index) {
        final item = songs[index];
        return _StreamSongTile(
          item: item,
          isLoading: _loadingSongId == item.id,
          onPlay: () => _streamSingleSong(item),
          onDownload: () => _downloadSong(item),
        );
      },
    );
  }

  Widget _buildAlbumsOnlyGrid() {
    final albums = _allAlbums;
    if (albums.isEmpty) {
      return Center(
        child: Text('No albums found.', style: GoogleFonts.outfit()),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: albums.length,
      itemBuilder: (ctx, idx) {
        final item = albums[idx];
        return _StreamCard(
          item: item,
          onTap: () => _openAlbumDetails(item),
        );
      },
    );
  }

  Widget _buildPlaylistsOnlyGrid() {
    final playlists = _allPlaylists;
    if (playlists.isEmpty) {
      return Center(
        child: Text('No playlists found.', style: GoogleFonts.outfit()),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: playlists.length,
      itemBuilder: (ctx, idx) {
        final item = playlists[idx];
        return _StreamCard(
          item: item,
          onTap: () => _openAlbumDetails(item),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: const Color(0xFF2BC5B4)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: const Color(0xFF2BC5B4),
              ),
              child: Text(actionLabel, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCardList(List<JioSaavnItem> items) {
    return SizedBox(
      height: 215,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          return _StreamCard(
            item: item,
            onTap: () {
              if (item.isSong) {
                _streamSingleSong(item);
              } else {
                _openAlbumDetails(item);
              }
            },
          );
        },
      ),
    );
  }
}

/// Song tile for immediate direct playback
class _StreamSongTile extends StatelessWidget {
  final JioSaavnItem item;
  final bool isLoading;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  const _StreamSongTile({
    required this.item,
    this.isLoading = false,
    required this.onPlay,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songId = int.tryParse(item.id) ?? (item.id.isNotEmpty ? item.id : item.token).hashCode.abs();
    final isCached = StreamCacheService.instance.isSongCached(songId);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AlbumArtWidget(
          albumArt: item.imageUrl,
          width: 50,
          height: 50,
          fallbackIcon: Icons.music_note_rounded,
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
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2BC5B4).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '320k',
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: const Color(0xFF2BC5B4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isCached)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.offline_pin_rounded,
                size: 11,
                color: Colors.greenAccent,
              ),
            ),
          Expanded(
            child: Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 20),
            tooltip: 'Download',
            onPressed: isLoading ? null : onDownload,
          ),
          isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2BC5B4),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF2BC5B4), size: 28),
                  tooltip: 'Stream',
                  onPressed: onPlay,
                ),
        ],
      ),
      onTap: isLoading ? null : onPlay,
    );
  }
}

class _StreamCard extends StatelessWidget {
  final JioSaavnItem item;
  final VoidCallback onTap;

  const _StreamCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final badgeText = item.isSong ? 'SONG' : (item.isAlbum ? 'ALBUM' : 'PLAYLIST');
    final badgeColor = item.isSong
        ? const Color(0xFF2BC5B4)
        : (item.isAlbum ? Colors.indigoAccent : Colors.amber.shade800);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork with play icon & type pill
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 140,
                    height: 140,
                    color: isDark ? const Color(0xFF242432) : Colors.grey[200],
                    child: AlbumArtWidget(
                      albumArt: item.imageUrl,
                      width: 140,
                      height: 140,
                      fallbackIcon: item.isSong
                          ? Icons.music_note_rounded
                          : Icons.album_rounded,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2BC5B4),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
                // Item Type Badge (SONG / ALBUM / PLAYLIST)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: item.isSong ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.subtitle.isNotEmpty ? item.subtitle : badgeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumTracksSheet extends StatefulWidget {
  final JioSaavnItem item;
  const _AlbumTracksSheet({required this.item});

  @override
  State<_AlbumTracksSheet> createState() => _AlbumTracksSheetState();
}

class _AlbumTracksSheetState extends State<_AlbumTracksSheet> {
  bool _isLoading = true;
  List<JioSaavnItem> _tracks = [];

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final list = widget.item.isAlbum
        ? await JioSaavnDecoder.fetchAlbumSongs(widget.item.token)
        : await JioSaavnDecoder.fetchPlaylistSongs(widget.item.token);

    if (!mounted) return;
    setState(() {
      _tracks = list;
      _isLoading = false;
    });
  }

  void _streamTrack(int index) {
    if (_tracks.isEmpty) return;
    final songs = _tracks.map((t) => t.toSong(albumName: widget.item.title)).toList();
    context.read<PlayerBloc>().add(PlayQueueEvent(songs, initialIndex: index));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Streaming "${songs[index].title}"', style: GoogleFonts.outfit()),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (getIt<SettingsService>().autoDownloadStreamSongs && index < _tracks.length) {
      _downloadTrack(_tracks[index]);
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
        album: widget.item.title,
        albumArt: track.imageUrl.isNotEmpty ? track.imageUrl : widget.item.imageUrl,
        duration: secs > 0 ? Duration(seconds: secs) : null,
      );
      showDownloadQueuedSnackBar(context, title: track.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AlbumArtWidget(
                      albumArt: widget.item.imageUrl,
                      width: 60,
                      height: 60,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(Icons.high_quality_rounded, size: 14, color: Color(0xFF2BC5B4)),
                            SizedBox(width: 4),
                            Text(
                              '320 kbps Stream • JioSaavn',
                              style: TextStyle(fontSize: 11, color: Color(0xFF2BC5B4), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_tracks.isNotEmpty)
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF2BC5B4),
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      tooltip: 'Play All',
                      onPressed: () => _streamTrack(0),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Tracks List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2BC5B4)))
                  : _tracks.isEmpty
                      ? const Center(child: Text('No playable tracks found.'))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: _tracks.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 64,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          itemBuilder: (ctx, index) {
                            final track = _tracks[index];
                            return ListTile(
                              leading: SizedBox(
                                width: 36,
                                height: 36,
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                track.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.download_rounded, size: 20),
                                    tooltip: 'Download',
                                    onPressed: () => _downloadTrack(track),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.play_circle_fill_rounded,
                                        color: Color(0xFF2BC5B4), size: 28),
                                    tooltip: 'Stream',
                                    onPressed: () => _streamTrack(index),
                                  ),
                                ],
                              ),
                              onTap: () => _streamTrack(index),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

extension SongToJioSaavnItem on Song {
  JioSaavnItem toJioSaavnItem() {
    return JioSaavnItem(
      type: 'song',
      id: id.toString(),
      token: id.toString(),
      title: title,
      subtitle: artist,
      imageUrl: albumArt ?? '',
      directMediaUrl: filePath,
      duration: duration.inSeconds.toString(),
      quality: audioQuality ?? '320 kbps',
    );
  }
}
