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
import 'package:pixel_player/presentation/screens/home_screen.dart';
import 'package:pixel_player/presentation/widgets/album_art_widget.dart';
import 'package:pixel_player/presentation/widgets/download_queue_snackbar.dart';
import 'package:pixel_player/services/download_service.dart';
import 'package:pixel_player/services/settings_service.dart';
import 'package:pixel_player/services/stream_cache_service.dart';
import 'package:pixel_player/services/user_taste_service.dart';
import 'package:pixel_player/services/stream_favorites_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  int _selectedFilter = 0; // 0: All, 1: Songs, 2: Albums, 3: Playlists, 4: Favorites, 5: Last Played, 6: Offline Cache
  bool _showSupportBanner = false;

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
    final settings = getIt<SettingsService>();
    _currentLang = settings.streamLanguage;
    _showSupportBanner = settings.shouldShowSupportBanner;
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

      // 3. Fetch new releases, home feed, and PulseIQ personalized suggestions in parallel
      final results = await Future.wait([
        JioSaavnDecoder.fetchNewReleases(lang: _currentLang),
        JioSaavnDecoder.fetchHomeFeed(lang: _currentLang),
        UserTasteService.instance.getPersonalizedSuggestions(
          topPlayed: _topPlayed,
          streamHistory: _lastPlayedStreamSongs,
          favorites: StreamFavoritesService.instance.favorites,
          lang: _currentLang,
          limit: 30,
        ),
      ]);

      final newReleases = results[0] as List<JioSaavnItem>;
      final homeModules = results[1] as Map<String, List<JioSaavnItem>>;
      List<JioSaavnItem> suggestions = results[2] as List<JioSaavnItem>;

      // Fallback seed if suggestions are empty (e.g., initial start or offline network glitch)
      if (suggestions.isEmpty) {
        String? seedId;
        for (final list in homeModules.values) {
          for (final item in list) {
            if (item.isSong && item.id.isNotEmpty) {
              seedId = item.id;
              break;
            }
          }
          if (seedId != null) break;
        }
        seedId ??= newReleases.where((i) => i.isSong && i.id.isNotEmpty).firstOrNull?.id;
        if (seedId != null && seedId.isNotEmpty) {
          suggestions = await JioSaavnDecoder.fetchSongSuggestions(seedId, limit: 25);
        }
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
    final fromSearch = _isSearching;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF181824)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AlbumTracksSheet(
        item: album,
        fromSearch: fromSearch,
      ),
    );
  }

  void _openSuggestedSongsDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF181824)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SuggestedSongsSheet(
        songs: _suggestedSongs,
        hasPersonalization: _topPlayed.isNotEmpty || StreamFavoritesService.instance.favorites.isNotEmpty,
      ),
    );
  }

  Future<void> _streamSingleSong(
    JioSaavnItem item, {
    List<JioSaavnItem>? contextQueue,
    List<Song>? contextSongQueue,
    bool fromSearch = false,
  }) async {
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
              content: Text('Stream proxy could not load "${item.title}". You can download it from YouTube in Library.', style: GoogleFonts.outfit()),
              action: SnackBarAction(
                label: 'YouTube',
                textColor: const Color(0xFF2BC5B4),
                onPressed: () => HomeScreen.switchToTab(0),
              ),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final song = item.toSong(overrideStreamUrl: streamUrl);
      if (!mounted) return;

      List<Song> queueToPlay;
      if (fromSearch) {
        queueToPlay = [song];
        UserTasteService.instance.recordSearchPlay(song, item: item);
      } else if (contextSongQueue != null && contextSongQueue.isNotEmpty) {
        queueToPlay = contextSongQueue.map((s) => s.id == song.id ? song : s).toList();
        if (!queueToPlay.any((s) => s.id == song.id)) {
          queueToPlay.insert(0, song);
        }
      } else if (contextQueue != null && contextQueue.isNotEmpty) {
        queueToPlay = contextQueue.map((it) => it.id == item.id ? song : it.toSong()).toList();
        if (!queueToPlay.any((s) => s.id == song.id)) {
          queueToPlay.insert(0, song);
        }
      } else {
        queueToPlay = [song];
      }

      context.read<PlayerBloc>().add(PlaySongEvent(song, queue: queueToPlay));
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _loadLastPlayedSongs();
      });


      UserTasteService.instance.getCandidateRecommendations(
        context: RecommendationContext.home,
        currentSong: song,
        recentHistory: _lastPlayedStreamSongs,
        lang: _currentLang,
        limit: 30,
      ).then((suggestions) {
        if (mounted && suggestions.isNotEmpty) {
          setState(() => _suggestedSongs = suggestions);
        }
      }).catchError((_) {});

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
            content: Text('Stream proxy error: $e. You can search & download this from YouTube in Library.', style: GoogleFonts.outfit()),
            action: SnackBarAction(
              label: 'Library',
              textColor: const Color(0xFF2BC5B4),
              onPressed: () => HomeScreen.switchToTab(0),
            ),
            duration: const Duration(seconds: 5),
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

  void _addSongToQueue(JioSaavnItem item) {
    final song = item.toSong();
    context.read<PlayerBloc>().add(AddToQueueEvent(song));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${item.title}" to queue', style: GoogleFonts.outfit()),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                onPlay: () => _streamSingleSong(song, fromSearch: true),
                onDownload: () => _downloadSong(song),
                onAddToQueue: () => _addSongToQueue(song),
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
              ? _buildStreamFailureView()
              : RefreshIndicator(
                  color: const Color(0xFF2BC5B4),
                  onRefresh: _loadStreamData,
                  child: _buildBodyContent(langName, allSongs),
                ),
    );
  }

  Widget _buildFilterChips() {
    final cachedCount = StreamCacheService.instance.cachedCount;
    final filters = [
      'All',
      'Songs',
      'Albums',
      'Playlists',
      'Favorites',
      'Last Played',
      if (cachedCount > 0) 'Offline Cache ($cachedCount)' else 'Offline Cache',
    ];

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
      // FAVORITES VIEW
      return _buildFavoritesView();
    } else if (_selectedFilter == 5) {
      // LAST PLAYED (HISTORY) VIEW
      return _buildLastPlayedView();
    } else if (_selectedFilter == 6) {
      // OFFLINE CACHE VIEW
      return _buildCachedSongsView();
    }

    // ALL (Default overview)
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        // 0. Support Project GitHub Banner
        _buildSupportBanner(),

        // 2. Last Played Stream History (if any)
        if (_lastPlayedStreamSongs.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Last Played',
            subtitle: 'Recently streamed songs',
            icon: Icons.history_rounded,
            actionLabel: _lastPlayedStreamSongs.length > 5 ? 'See All (${_lastPlayedStreamSongs.length})' : null,
            onAction: () => setState(() => _selectedFilter = 5),
          ),
          ..._lastPlayedStreamSongs.take(5).map((song) {
            final item = song.toJioSaavnItem();
            return _StreamSongTile(
              item: item,
              isLoading: _loadingSongId == item.id,
              onPlay: () => _streamSingleSong(
                item,
                contextSongQueue: _lastPlayedStreamSongs,
              ),
              onDownload: () => _downloadSong(item),
              onAddToQueue: () => _addSongToQueue(item),
            );
          }),
          const SizedBox(height: 16),
        ],

        // 1. Song Suggestions (PulseIQ Multi-Seed & Composer Radar)
        if (_suggestedSongs.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Song Suggestions',
            subtitle: (_topPlayed.isNotEmpty || StreamFavoritesService.instance.favorites.isNotEmpty)
                ? 'Curated from your favorite artists & composers'
                : 'Recommended songs for you',
            icon: Icons.recommend_rounded,
            actionLabel: _suggestedSongs.length > 6 ? 'See All (${_suggestedSongs.length})' : null,
            onAction: _openSuggestedSongsDetails,
          ),
          ..._suggestedSongs.take(10).map((item) => _StreamSongTile(
                item: item,
                isLoading: _loadingSongId == item.id,
                onPlay: () => _streamSingleSong(
                  item,
                  contextQueue: _suggestedSongs,
                ),
                onDownload: () => _downloadSong(item),
                onAddToQueue: () => _addSongToQueue(item),
              )),
          const SizedBox(height: 16),
        ],

        // 2. Trending Songs (Directly playable single songs)
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
                onPlay: () => _streamSingleSong(
                  item,
                  contextQueue: allSongs,
                ),
                onDownload: () => _downloadSong(item),
                onAddToQueue: () => _addSongToQueue(item),
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
          onPlay: () => _streamSingleSong(
            item,
            contextSongQueue: _lastPlayedStreamSongs,
          ),
          onDownload: () => _downloadSong(item),
          onAddToQueue: () => _addSongToQueue(item),
        );
      },
    );
  }

  Widget _buildFavoritesView() {
    return StreamBuilder<List<Song>>(
      stream: StreamFavoritesService.instance.onFavoritesChanged,
      initialData: StreamFavoritesService.instance.favorites,
      builder: (context, snapshot) {
        final favorites = snapshot.data ?? StreamFavoritesService.instance.favorites;
        if (favorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No stream favorites yet',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap the heart icon on any streamed song to add it here',
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
          itemCount: favorites.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (ctx, index) {
            final song = favorites[index];
            final item = song.toJioSaavnItem();
            return _StreamSongTile(
              item: item,
              isLoading: _loadingSongId == item.id,
              onPlay: () => _streamSingleSong(
                item,
                contextSongQueue: favorites,
              ),
              onDownload: () => _downloadSong(item),
              onAddToQueue: () => _addSongToQueue(item),
            );
          },
        );
      },
    );
  }

  Widget _buildSupportBanner() {
    if (!_showSupportBanner) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF1E2A38),
                    const Color(0xFF18202A),
                  ]
                : [
                    const Color(0xFFE8F4FD),
                    const Color(0xFFF0F8FF),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF2BC5B4).withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2BC5B4).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFF2BC5B4),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Support This Project',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2BC5B4).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'GitHub',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2BC5B4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enjoying Pixel Player? Star our GitHub repo to support development, track updates, and help the project grow!',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          height: 1.35,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Dismiss banner',
                  onPressed: () {
                    setState(() => _showSupportBanner = false);
                    getIt<SettingsService>().dismissSupportBanner();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2BC5B4),
                    foregroundColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.star_rate_rounded, size: 16),
                  label: Text(
                    'Star on GitHub',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: _openGitHubRepo,
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(
                    'View Repo',
                    style: GoogleFonts.outfit(fontSize: 12),
                  ),
                  onPressed: _openGitHubRepo,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGitHubRepo() async {
    getIt<SettingsService>().dismissSupportBanner();
    setState(() => _showSupportBanner = false);
    const urlString = 'https://github.com/Ashutosh-rajput/flutter_application_1';
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $urlString: $e', style: GoogleFonts.outfit()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildCachedSongsView() {
    final cachedItems = StreamCacheService.instance.getCachedItems();
    final cachedSongs = StreamCacheService.instance.getCachedSongs();

    if (cachedItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cached_rounded, size: 48, color: Colors.orange),
              ),
              const SizedBox(height: 16),
              Text(
                'No Cached Stream Songs Yet',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Songs you stream are automatically saved here (up to 50 songs) for instant offline playback without proxy APIs.\n\nYou can also search and download any song from YouTube via the Library tab.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2BC5B4),
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.library_music_rounded, size: 18),
                label: const Text('Go to Library & YouTube'),
                onPressed: () => HomeScreen.switchToTab(0),
              ),
            ],
          ),
        ),
      );
    }

    final totalMb = StreamCacheService.instance.totalSizeMb.toStringAsFixed(1);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2BC5B4).withValues(alpha: 0.15),
                  Colors.green.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF2BC5B4).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2BC5B4).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.offline_pin_rounded, color: Color(0xFF2BC5B4), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cachedItems.length} Cached Songs ($totalMb MB)',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Saved locally • Plays 100% offline without proxy API',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF2BC5B4),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 26),
                  tooltip: 'Play All Cached Songs',
                  onPressed: () {
                    context.read<PlayerBloc>().add(PlayQueueEvent(cachedSongs, initialIndex: 0));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Playing ${cachedSongs.length} offline cached songs', style: GoogleFonts.outfit()),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...cachedItems.map((item) => _StreamSongTile(
              item: item,
              isLoading: _loadingSongId == item.id,
              onPlay: () => _streamSingleSong(
                item,
                contextQueue: cachedItems,
              ),
              onDownload: () => _downloadSong(item),
              onAddToQueue: () => _addSongToQueue(item),
            )),
      ],
    );
  }

  Widget _buildStreamFailureView() {
    final cachedSongs = StreamCacheService.instance.getCachedSongs();
    final cachedItems = StreamCacheService.instance.getCachedItems();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Error & Proxy Alert Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C1E1A) : const Color(0xFFFFF0EC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Streaming Service Unavailable',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        Text(
                          'Proxy API is down or connection timed out',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Streaming APIs connect to public proxies which may stop working at any moment. In the meantime, use the Library to search & download tracks from YouTube, or play your saved offline songs below.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download on YouTube'),
                      onPressed: () => HomeScreen.switchToTab(0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                    onPressed: _loadStreamData,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // If user has cached songs, show them immediately so music never stops!
        if (cachedItems.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Offline Stream Cache (${cachedItems.length})',
            subtitle: 'Saved on your device • Plays without proxy API',
            icon: Icons.offline_pin_rounded,
            actionLabel: 'Play All',
            onAction: () {
              context.read<PlayerBloc>().add(PlayQueueEvent(cachedSongs, initialIndex: 0));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Playing ${cachedSongs.length} offline cached songs', style: GoogleFonts.outfit()),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          ...cachedItems.map((item) => _StreamSongTile(
                item: item,
                isLoading: _loadingSongId == item.id,
                onPlay: () => _streamSingleSong(
                  item,
                  contextQueue: cachedItems,
                ),
                onDownload: () => _downloadSong(item),
                onAddToQueue: () => _addSongToQueue(item),
              )),
        ] else ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.library_music_rounded, size: 48, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'No songs cached yet',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Switch to the Library tab to search and download high-quality tracks directly from YouTube.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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
          onPlay: () => _streamSingleSong(
            item,
            contextQueue: songs,
          ),
          onDownload: () => _downloadSong(item),
          onAddToQueue: () => _addSongToQueue(item),
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
                final songItems = items.where((i) => i.isSong).toList();
                _streamSingleSong(
                  item,
                  contextQueue: songItems,
                );
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
  final VoidCallback? onAddToQueue;

  const _StreamSongTile({
    required this.item,
    this.isLoading = false,
    required this.onPlay,
    required this.onDownload,
    this.onAddToQueue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songId = item.stableId;
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
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2BC5B4),
                ),
              ),
            ),
          if (onAddToQueue != null)
            IconButton(
              icon: const Icon(Icons.playlist_add_rounded, size: 22),
              tooltip: 'Add to queue',
              visualDensity: VisualDensity.compact,
              onPressed: onAddToQueue,
            ),
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 20),
            tooltip: 'Download',
            visualDensity: VisualDensity.compact,
            onPressed: isLoading ? null : onDownload,
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

class _SuggestedSongsSheet extends StatelessWidget {
  final List<JioSaavnItem> songs;
  final bool hasPersonalization;

  const _SuggestedSongsSheet({
    required this.songs,
    required this.hasPersonalization,
  });

  Future<void> _streamTrack(BuildContext context, int index) async {
    if (songs.isEmpty || index < 0 || index >= songs.length) return;
    final messenger = ScaffoldMessenger.of(context);
    final targetTrack = songs[index];

    String? directUrl = targetTrack.directMediaUrl ?? JioSaavnDecoder.decryptMediaUrl(targetTrack.encryptedMediaUrl);
    if (directUrl == null || directUrl.isEmpty) {
      final details = await JioSaavnDecoder.fetchSongDetails(targetTrack.token.isNotEmpty ? targetTrack.token : targetTrack.id);
      directUrl = details?.directMediaUrl ?? JioSaavnDecoder.decryptMediaUrl(details?.encryptedMediaUrl);
    }

    final songModels = songs.map((t) {
      final s = t.toSong(albumName: 'Song Suggestions');
      if (t.id == targetTrack.id && directUrl != null && directUrl.isNotEmpty) {
        return s.copyWith(filePath: directUrl);
      }
      return s;
    }).toList();

    if (!context.mounted) return;
    context.read<PlayerBloc>().add(PlayQueueEvent(songModels, initialIndex: index));
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Streaming "${songModels[index].title}"', style: GoogleFonts.outfit()),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (getIt<SettingsService>().autoDownloadStreamSongs && index < songs.length) {
      _downloadTrack(context, songs[index]);
    }
  }

  void _addTrackToQueue(BuildContext context, JioSaavnItem track) {
    final song = track.toSong(albumName: 'Song Suggestions');
    context.read<PlayerBloc>().add(AddToQueueEvent(song));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${track.title}" to queue', style: GoogleFonts.outfit()),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _downloadTrack(BuildContext context, JioSaavnItem track) {
    final downloadService = getIt<DownloadService>();
    final directUrl = track.directMediaUrl ?? JioSaavnDecoder.decryptMediaUrl(track.encryptedMediaUrl);
    if (directUrl != null) {
      final secs = int.tryParse(track.duration ?? '0') ?? 0;
      downloadService.enqueueDownload(
        url: directUrl,
        title: track.title,
        artist: track.subtitle,
        album: 'Song Suggestions',
        albumArt: track.imageUrl,
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
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2BC5B4).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.recommend_rounded,
                      color: Color(0xFF2BC5B4),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Song Suggestions (${songs.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasPersonalization
                              ? 'Curated from your favorite artists & composers'
                              : 'Recommended songs for you',
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
                            Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF2BC5B4)),
                            SizedBox(width: 4),
                            Text(
                              'PulseIQ Recommendation Engine',
                              style: TextStyle(fontSize: 11, color: Color(0xFF2BC5B4), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (songs.isNotEmpty)
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF2BC5B4),
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      tooltip: 'Play All',
                      onPressed: () => _streamTrack(context, 0),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: songs.isEmpty
                  ? const Center(child: Text('No song suggestions available.'))
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: songs.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 72,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      itemBuilder: (ctx, index) {
                        final track = songs[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AlbumArtWidget(
                              albumArt: track.imageUrl,
                              width: 44,
                              height: 44,
                              fallbackIcon: Icons.music_note_rounded,
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
                                icon: const Icon(Icons.playlist_add_rounded, size: 22),
                                tooltip: 'Add to queue',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _addTrackToQueue(context, track),
                              ),
                              IconButton(
                                icon: const Icon(Icons.download_rounded, size: 20),
                                tooltip: 'Download',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _downloadTrack(context, track),
                              ),
                            ],
                          ),
                          onTap: () => _streamTrack(context, index),
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

class _AlbumTracksSheet extends StatefulWidget {
  final JioSaavnItem item;
  final bool fromSearch;
  const _AlbumTracksSheet({required this.item, this.fromSearch = false});

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

  Future<void> _streamTrack(int index) async {
    if (_tracks.isEmpty || index < 0 || index >= _tracks.length) return;
    final messenger = ScaffoldMessenger.of(context);
    final targetTrack = _tracks[index];

    // Ensure direct stream URL is available for the selected track
    String? directUrl = targetTrack.directMediaUrl ?? JioSaavnDecoder.decryptMediaUrl(targetTrack.encryptedMediaUrl);
    if (directUrl == null || directUrl.isEmpty) {
      final details = await JioSaavnDecoder.fetchSongDetails(targetTrack.token.isNotEmpty ? targetTrack.token : targetTrack.id);
      directUrl = details?.directMediaUrl ?? JioSaavnDecoder.decryptMediaUrl(details?.encryptedMediaUrl);
    }

    final songs = _tracks.map((t) {
      final s = t.toSong(albumName: widget.item.title);
      if (t.id == targetTrack.id && directUrl != null && directUrl.isNotEmpty) {
        return s.copyWith(filePath: directUrl);
      }
      return s;
    }).toList();

    if (!mounted) return;
    if (widget.fromSearch && index < songs.length) {
      UserTasteService.instance.recordSearchPlay(songs[index], item: targetTrack);
    }
    context.read<PlayerBloc>().add(PlayQueueEvent(songs, initialIndex: index));
    Navigator.pop(context);
    messenger.showSnackBar(
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

  void _addTrackToQueue(JioSaavnItem track) {
    final song = track.toSong(albumName: widget.item.title);
    context.read<PlayerBloc>().add(AddToQueueEvent(song));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${track.title}" to queue', style: GoogleFonts.outfit()),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                            indent: 72,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          itemBuilder: (ctx, index) {
                            final track = _tracks[index];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AlbumArtWidget(
                                  albumArt: track.imageUrl.isNotEmpty ? track.imageUrl : widget.item.imageUrl,
                                  width: 44,
                                  height: 44,
                                  fallbackIcon: Icons.music_note_rounded,
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
                                    icon: const Icon(Icons.playlist_add_rounded, size: 22),
                                    tooltip: 'Add to queue',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _addTrackToQueue(track),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.download_rounded, size: 20),
                                    tooltip: 'Download',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _downloadTrack(track),
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
