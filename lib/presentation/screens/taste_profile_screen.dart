import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinyl/presentation/widgets/album_art_widget.dart';
import 'package:vinyl/services/user_taste_service.dart';

class TasteProfileScreen extends StatefulWidget {
  const TasteProfileScreen({super.key});

  @override
  State<TasteProfileScreen> createState() => _TasteProfileScreenState();
}

class _TasteProfileScreenState extends State<TasteProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _addArtistController = TextEditingController();
  final TextEditingController _songSearchController = TextEditingController();
  final TextEditingController _artistSearchController = TextEditingController();

  String _songQuery = '';
  String _artistQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addArtistController.dispose();
    _songSearchController.dispose();
    _artistSearchController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit()),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _confirmResetProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Taste Profile?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'This will remove all tracked suggestion songs, play history signals, and artist affinities. Recommendations will start fresh.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reset All', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await UserTasteService.instance.clearTasteProfile();
      setState(() {});
      _showSnackBar('Taste profile reset successfully.');
    }
  }

  String _capitalizeWords(String str) {
    if (str.isEmpty) return str;
    return str.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = theme.colorScheme.primary;

    final songs = UserTasteService.instance.getTrackedSongs(query: _songQuery);
    final artists = UserTasteService.instance.getTrackedArtists(query: _artistQuery);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Taste Profile & Suggestions',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            tooltip: 'Reset Taste Profile',
            onPressed: _confirmResetProfile,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: accentColor,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Artists (${UserTasteService.instance.trackedArtistCount})'),
            Tab(text: 'Songs (${UserTasteService.instance.trackedSongCount})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildArtistsTab(artists, isDark, accentColor),
          _buildSongsTab(songs, isDark, accentColor),
        ],
      ),
    );
  }

  Widget _buildArtistsTab(
    List<MapEntry<String, double>> artists,
    bool isDark,
    Color accentColor,
  ) {
    return Column(
      children: [
        // Add Artist input card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addArtistController,
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add preferred artist (e.g. Arijit Singh)...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    prefixIcon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E1E28) : const Color(0xFFF2F2F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (value) async {
                    final text = value.trim();
                    if (text.isNotEmpty) {
                      await UserTasteService.instance.addPreferredArtist(text);
                      _addArtistController.clear();
                      setState(() {});
                      _showSnackBar('Added "$text" to recommendation preferences!');
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onPressed: () async {
                  final text = _addArtistController.text.trim();
                  if (text.isNotEmpty) {
                    await UserTasteService.instance.addPreferredArtist(text);
                    _addArtistController.clear();
                    setState(() {});
                    _showSnackBar('Added "$text" to recommendation preferences!');
                  }
                },
                child: Text('Add', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Filter search input
        if (artists.isNotEmpty || _artistQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _artistSearchController,
              style: GoogleFonts.outfit(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search tracked artists...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _artistQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _artistSearchController.clear();
                          setState(() => _artistQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: isDark ? const Color(0xFF191922) : const Color(0xFFEBEBF0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _artistQuery = val),
            ),
          ),

        const SizedBox(height: 4),

        // Artists list
        Expanded(
          child: artists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        _artistQuery.isEmpty
                            ? 'No tracked artists yet.\nPlay songs or add artists above to customize suggestions.'
                            : 'No artists matching "$_artistQuery"',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.grey, height: 1.4),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 40),
                  itemCount: artists.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                  itemBuilder: (context, index) {
                    final entry = artists[index];
                    final artistName = _capitalizeWords(entry.key);
                    final score = entry.value;
                    final isSearchPlayed = UserTasteService.instance.isSearchPlayedArtist(entry.key);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: accentColor.withValues(alpha: 0.18),
                        child: Text(
                          artistName.isNotEmpty ? artistName[0].toUpperCase() : '?',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                          if (isSearchPlayed) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'High Intent',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        'Affinity Score: ${score.toStringAsFixed(1)}',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                        tooltip: 'Remove artist from recommendations',
                        onPressed: () async {
                          final removedCount = await UserTasteService.instance.removeTrackedArtist(entry.key);
                          setState(() {});
                          _showSnackBar('Removed $artistName ($removedCount tracks pruned).');
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSongsTab(
    List<SongInteraction> songs,
    bool isDark,
    Color accentColor,
  ) {
    final now = DateTime.now();

    return Column(
      children: [
        // Song search filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _songSearchController,
            style: GoogleFonts.outfit(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search suggestion songs or artists...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _songQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _songSearchController.clear();
                        setState(() => _songQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E28) : const Color(0xFFF2F2F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _songQuery = val),
          ),
        ),

        // Songs list
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.library_music_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        _songQuery.isEmpty
                            ? 'No suggestion songs tracked yet.\nStream or search tracks to build your personalized radar.'
                            : 'No songs matching "$_songQuery"',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.grey, height: 1.4),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 40),
                  itemCount: songs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final score = song.computeAffinityScore(now);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AlbumArtWidget(
                          albumArt: song.imageUrl,
                          width: 48,
                          height: 48,
                        ),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${song.playCount} plays',
                                style: GoogleFonts.outfit(fontSize: 11, color: accentColor, fontWeight: FontWeight.bold),
                              ),
                              if (song.searchPlayCount > 0) ...[
                                const Text(' • ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(
                                  '${song.searchPlayCount} search plays',
                                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold),
                                ),
                              ],
                              if (song.skipCount > 0) ...[
                                const Text(' • ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(
                                  '${song.skipCount} skips',
                                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.redAccent),
                                ),
                              ],
                              const Text(' • ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(
                                'Score: ${score.toStringAsFixed(1)}',
                                style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                        tooltip: 'Remove track from recommendations',
                        onPressed: () async {
                          await UserTasteService.instance.removeTrackedSong(song.trackKey);
                          setState(() {});
                          _showSnackBar('Removed "${song.title}" from recommendations.');
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
