import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/services/settings_service.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';
import 'package:pixel_player/presentation/bloc/library/library_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsService _settingsService;

  // Playback State
  late bool _autoPlayNext;
  late String _repeatMode;
  late bool _shuffleByDefault;
  late bool _resumeLastSong;
  late double _defaultVolume;

  // Download Settings State
  late String _downloadQuality;
  late String _downloadFormat;
  late bool _autoDownloadPlaylistMetadata;
  late bool _skipAlreadyDownloaded;
  late bool _downloadOnlyOnWifi;
  late double _maxSimultaneousDownloads;

  // Appearance State
  late String _themeMode;
  late Color _accentColor;
  late int _accentColorIndex;
  late bool _amoledBlackMode;
  late String _fontSize;
  late String _albumArtSize;

  // Library State
  late bool _autoScanMusicFolder;
  late bool _ignoreShortAudio;
  late bool _showHiddenFiles;

  // Search State
  late bool _includeOnlineResults;
  late bool _saveSearchHistory;

  // Network State
  late bool _retryFailedDownloads;
  late int _downloadTimeoutSeconds;

  // Notifications State
  late bool _showPlaybackNotification;
  late bool _lockScreenControls;
  late bool _downloadNotifications;

  // Storage Stats (Real File System Calculation)
  double _musicSizeMb = 0.0;
  double _cacheSizeMb = 0.0;
  double _thumbnailsSizeMb = 0.0;
  bool _isLoadingStorageStats = true;

  final List<Color> _accentColors = const [
    Color(0xFF6C5CE7), // Purple
    Color(0xFF00CEC9), // Teal/Cyan
    Color(0xFFFD79A8), // Pink
    Color(0xFFFF7675), // Coral
    Color(0xFF0984E3), // Pixel Blue
    Color(0xFF00B894), // Emerald
  ];

  @override
  void initState() {
    super.initState();
    _settingsService = getIt<SettingsService>();
    _loadSettingsFromStorage();
    _loadStorageStats();
  }

  void _loadSettingsFromStorage() {
    _autoPlayNext = _settingsService.autoPlayNext;
    _repeatMode = _settingsService.repeatMode;
    _shuffleByDefault = _settingsService.shuffleByDefault;
    _resumeLastSong = _settingsService.resumeLastSong;
    _defaultVolume = _settingsService.defaultVolume;

    _downloadQuality = _settingsService.downloadQuality;
    _downloadFormat = _settingsService.downloadFormat;
    _autoDownloadPlaylistMetadata = _settingsService.autoDownloadPlaylistMetadata;
    _skipAlreadyDownloaded = _settingsService.skipAlreadyDownloaded;
    _downloadOnlyOnWifi = _settingsService.downloadOnlyOnWifi;
    _maxSimultaneousDownloads = _settingsService.maxSimultaneousDownloads.toDouble();

    _themeMode = _settingsService.themeMode;
    _accentColorIndex = _settingsService.accentColorIndex.clamp(0, _accentColors.length - 1);
    _accentColor = _accentColors[_accentColorIndex];
    _amoledBlackMode = _settingsService.amoledBlackMode;
    _fontSize = _settingsService.fontSize;
    _albumArtSize = _settingsService.albumArtSize;

    _autoScanMusicFolder = _settingsService.autoScanMusicFolder;
    _ignoreShortAudio = _settingsService.ignoreShortAudio;
    _showHiddenFiles = _settingsService.showHiddenFiles;

    _includeOnlineResults = _settingsService.includeOnlineResults;
    _saveSearchHistory = _settingsService.saveSearchHistory;

    _retryFailedDownloads = _settingsService.retryFailedDownloads;
    _downloadTimeoutSeconds = _settingsService.downloadTimeoutSeconds;

    _showPlaybackNotification = _settingsService.showPlaybackNotification;
    _lockScreenControls = _settingsService.lockScreenControls;
    _downloadNotifications = _settingsService.downloadNotifications;
  }

  Future<void> _loadStorageStats() async {
    setState(() => _isLoadingStorageStats = true);
    final stats = await _settingsService.calculateStorageSizes();
    if (mounted) {
      setState(() {
        _musicSizeMb = stats.musicSizeMb;
        _cacheSizeMb = stats.cacheSizeMb;
        _thumbnailsSizeMb = stats.thumbnailsSizeMb;
        _isLoadingStorageStats = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 120),
        children: [
          // PLAYBACK SECTION
          _buildSectionHeader('Playback'),
          _buildCardContainer(
            isDark: isDark,
            children: [
              SwitchListTile(
                title: _tileTitle('Auto Play Next'),
                subtitle: _tileSubtitle('Automatically queue next track when current ends'),
                value: _autoPlayNext,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _autoPlayNext = val);
                  _settingsService.setAutoPlayNext(val);
                },
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Repeat Mode'),
                subtitle: _tileSubtitle('Current: $_repeatMode'),
                trailing: DropdownButton<String>(
                  value: _repeatMode,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? const Color(0xFF232330) : Colors.white,
                  items: ['Off', 'One', 'All'].map((mode) {
                    return DropdownMenuItem(
                      value: mode,
                      child: Text(mode, style: GoogleFonts.outfit()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _repeatMode = val);
                      _settingsService.setRepeatMode(val);
                    }
                  },
                ),
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Shuffle by Default'),
                subtitle: _tileSubtitle('Enable shuffle automatically on playback'),
                value: _shuffleByDefault,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _shuffleByDefault = val);
                  _settingsService.setShuffleByDefault(val);
                },
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Resume Last Song'),
                subtitle: _tileSubtitle('Restore last played song on startup'),
                value: _resumeLastSong,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _resumeLastSong = val);
                  _settingsService.setResumeLastSong(val);
                },
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Default Volume'),
                subtitle: Slider(
                  value: _defaultVolume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: _accentColor,
                  onChanged: (val) {
                    setState(() => _defaultVolume = val);
                    _settingsService.setDefaultVolume(val);
                  },
                ),
                trailing: Text(
                  '${(_defaultVolume * 100).toInt()}%',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // DOWNLOADS SECTION
          _buildSectionHeader('Downloads'),
          _buildCardContainer(
            isDark: isDark,
            children: [
              ListTile(
                title: _tileTitle('Download Location'),
                subtitle: Text(
                  '/storage/emulated/0/Download/blackmusic',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: _accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.folder_special_rounded),
                onTap: () => _showSnackBar('Saved to: Internal Storage > Download > blackmusic'),
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Default Audio Quality'),
                subtitle: _tileSubtitle('Selected: $_downloadQuality'),
                trailing: DropdownButton<String>(
                  value: _downloadQuality,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? const Color(0xFF232330) : Colors.white,
                  items: ['Best', 'Medium', 'Low'].map((q) {
                    return DropdownMenuItem(
                      value: q,
                      child: Text(q, style: GoogleFonts.outfit()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _downloadQuality = val);
                      _settingsService.setDownloadQuality(val);
                    }
                  },
                ),
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Download Format'),
                subtitle: _tileSubtitle('Format: $_downloadFormat'),
                trailing: DropdownButton<String>(
                  value: _downloadFormat,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? const Color(0xFF232330) : Colors.white,
                  items: ['M4A', 'MP3'].map((f) {
                    return DropdownMenuItem(
                      value: f,
                      child: Text(f, style: GoogleFonts.outfit()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _downloadFormat = val);
                      _settingsService.setDownloadFormat(val);
                    }
                  },
                ),
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Download Playlist Metadata'),
                subtitle: _tileSubtitle('Fetch playlist title, artwork & author'),
                value: _autoDownloadPlaylistMetadata,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _autoDownloadPlaylistMetadata = val);
                  _settingsService.setAutoDownloadPlaylistMetadata(val);
                },
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Skip Already Downloaded Songs'),
                subtitle: _tileSubtitle('Avoid re-downloading existing library tracks'),
                value: _skipAlreadyDownloaded,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _skipAlreadyDownloaded = val);
                  _settingsService.setSkipAlreadyDownloaded(val);
                },
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Download Only on Wi-Fi'),
                subtitle: _tileSubtitle('Save mobile data during downloads'),
                value: _downloadOnlyOnWifi,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _downloadOnlyOnWifi = val);
                  _settingsService.setDownloadOnlyOnWifi(val);
                },
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Max Simultaneous Downloads'),
                subtitle: Slider(
                  value: _maxSimultaneousDownloads,
                  min: 1.0,
                  max: 3.0,
                  divisions: 2,
                  activeColor: _accentColor,
                  label: '${_maxSimultaneousDownloads.toInt()}',
                  onChanged: (val) {
                    setState(() => _maxSimultaneousDownloads = val);
                    _settingsService.setMaxSimultaneousDownloads(val.toInt());
                  },
                ),
                trailing: Text(
                  '${_maxSimultaneousDownloads.toInt()}',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // APPEARANCE SECTION
          _buildSectionHeader('Appearance'),
          _buildCardContainer(
            isDark: isDark,
            children: [
              ListTile(
                title: _tileTitle('Theme Mode'),
                subtitle: _tileSubtitle('Theme: $_themeMode'),
                trailing: DropdownButton<String>(
                  value: _themeMode,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? const Color(0xFF232330) : Colors.white,
                  items: ['System', 'Light', 'Dark'].map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(t, style: GoogleFonts.outfit()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _themeMode = val);
                      _settingsService.setThemeMode(val);
                    }
                  },
                ),
              ),
              _divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tileTitle('Accent Color'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_accentColors.length, (idx) {
                        final color = _accentColors[idx];
                        final isSelected = idx == _accentColorIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _accentColorIndex = idx;
                              _accentColor = color;
                            });
                            _settingsService.setAccentColorIndex(idx);
                          },
                          child: CircleAvatar(
                            backgroundColor: color,
                            radius: 18,
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('AMOLED Black Mode'),
                subtitle: _tileSubtitle('Pure dark background for OLED displays'),
                value: _amoledBlackMode,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _amoledBlackMode = val);
                  _settingsService.setAmoledBlackMode(val);
                },
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Font Size'),
                trailing: DropdownButton<String>(
                  value: _fontSize,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? const Color(0xFF232330) : Colors.white,
                  items: ['Small', 'Medium', 'Large'].map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s, style: GoogleFonts.outfit()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _fontSize = val);
                      _settingsService.setFontSize(val);
                    }
                  },
                ),
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Album Art Size'),
                trailing: DropdownButton<String>(
                  value: _albumArtSize,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? const Color(0xFF232330) : Colors.white,
                  items: ['Compact', 'Medium', 'Large'].map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s, style: GoogleFonts.outfit()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _albumArtSize = val);
                      _settingsService.setAlbumArtSize(val);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // LIBRARY SECTION
          _buildSectionHeader('Library'),
          _buildCardContainer(
            isDark: isDark,
            children: [
              SwitchListTile(
                title: _tileTitle('Auto Scan Music Folder'),
                subtitle: _tileSubtitle('Detect new files automatically'),
                value: _autoScanMusicFolder,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _autoScanMusicFolder = val);
                  _settingsService.setAutoScanMusicFolder(val);
                },
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Scan Music Directory'),
                subtitle: _tileSubtitle('Rescan local storage & add new music files'),
                trailing: const Icon(Icons.refresh_rounded),
                onTap: () async {
                  final bloc = context.read<LibraryBloc>();
                  _showSnackBar('Scanning local storage...');
                  final added = await _settingsService.rescanMusicLibrary();
                  bloc.add(const LoadLibraryEvent());
                  _showSnackBar('Library updated! Found $added audio tracks.');
                  _loadStorageStats();
                },
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Ignore Short Audio (<30 sec)'),
                subtitle: _tileSubtitle('Filter out ringtones & voice notes'),
                value: _ignoreShortAudio,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _ignoreShortAudio = val);
                  _settingsService.setIgnoreShortAudio(val);
                },
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Clear Missing Songs'),
                subtitle: _tileSubtitle('Remove deleted files from database'),
                trailing: const Icon(Icons.cleaning_services_rounded),
                onTap: () async {
                  final bloc = context.read<LibraryBloc>();
                  final removed = await _settingsService.clearMissingSongs();
                  bloc.add(const LoadLibraryEvent());
                  _showSnackBar('Cleaned $removed missing tracks from library.');
                  _loadStorageStats();
                },
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Show Hidden Files'),
                subtitle: _tileSubtitle('Include hidden system audio files'),
                value: _showHiddenFiles,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _showHiddenFiles = val);
                  _settingsService.setShowHiddenFiles(val);
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // SEARCH SECTION
          _buildSectionHeader('Search'),
          _buildCardContainer(
            isDark: isDark,
            children: [
              SwitchListTile(
                title: _tileTitle('Include Online Results'),
                subtitle: _tileSubtitle('Search YouTube and online sources'),
                value: _includeOnlineResults,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _includeOnlineResults = val);
                  _settingsService.setIncludeOnlineResults(val);
                },
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Save Search History'),
                subtitle: _tileSubtitle('Keep track of recent search queries'),
                value: _saveSearchHistory,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _saveSearchHistory = val);
                  _settingsService.setSaveSearchHistory(val);
                },
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Clear Search History'),
                subtitle: _tileSubtitle('Remove all saved search suggestions'),
                trailing: const Icon(Icons.history_toggle_off_rounded),
                onTap: () => _showSnackBar('Search history cleared.'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // NETWORK & ADVANCED
          _buildSectionHeader('Network & Advanced'),
          _buildCardContainer(
            isDark: isDark,
            children: [
              SwitchListTile(
                title: _tileTitle('Retry Failed Downloads'),
                subtitle: _tileSubtitle('Auto-retry on network disconnects'),
                value: _retryFailedDownloads,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _retryFailedDownloads = val);
                  _settingsService.setRetryFailedDownloads(val);
                },
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Download Timeout'),
                trailing: DropdownButton<int>(
                  value: _downloadTimeoutSeconds,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? const Color(0xFF232330) : Colors.white,
                  items: [30, 60, 120].map((sec) {
                    return DropdownMenuItem(
                      value: sec,
                      child: Text('${sec}s', style: GoogleFonts.outfit()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _downloadTimeoutSeconds = val);
                      _settingsService.setDownloadTimeoutSeconds(val);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // NOTIFICATIONS SECTION
          _buildSectionHeader('Notifications'),
          _buildCardContainer(
            isDark: isDark,
            children: [
              SwitchListTile(
                title: _tileTitle('Show Playback Notification'),
                subtitle: _tileSubtitle('Display media controls in system status bar'),
                value: _showPlaybackNotification,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _showPlaybackNotification = val);
                  _settingsService.setShowPlaybackNotification(val);
                },
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Lock Screen Controls'),
                subtitle: _tileSubtitle('Enable music playback widget on lock screen'),
                value: _lockScreenControls,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _lockScreenControls = val);
                  _settingsService.setLockScreenControls(val);
                },
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Download Notifications'),
                subtitle: _tileSubtitle('Show download progress & completion alerts'),
                value: _downloadNotifications,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _downloadNotifications = val);
                  _settingsService.setDownloadNotifications(val);
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // STORAGE & CACHE SECTION
          _buildSectionHeader('Storage & Cache'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E28) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isLoadingStorageStats
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Column(
                    children: [
                      _storageRow('Music Files', '${(_musicSizeMb / 1024).toStringAsFixed(2)} GB (${_musicSizeMb.toStringAsFixed(1)} MB)', Colors.blueAccent),
                      const SizedBox(height: 12),
                      _storageRow('Cache', '${_cacheSizeMb.toStringAsFixed(1)} MB', Colors.orangeAccent),
                      const SizedBox(height: 12),
                      _storageRow('Thumbnails', '${_thumbnailsSizeMb.toStringAsFixed(1)} MB', Colors.purpleAccent),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: Text('Clear Cache', style: GoogleFonts.outfit()),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                await _settingsService.clearCache();
                                _showSnackBar('App cache cleared!');
                                _loadStorageStats();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.image_not_supported_outlined, size: 18),
                              label: Text('Clear Art', style: GoogleFonts.outfit()),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                await _settingsService.clearThumbnails();
                                _showSnackBar('Thumbnails cache cleared!');
                                _loadStorageStats();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: _accentColor,
        ),
      ),
    );
  }

  Widget _buildCardContainer({required bool isDark, required List<Widget> children}) {
    return Material(
      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _tileTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    );
  }

  Widget _tileSubtitle(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
    );
  }

  Widget _storageRow(String label, String value, Color indicatorColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.outfit(fontSize: 14)),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
