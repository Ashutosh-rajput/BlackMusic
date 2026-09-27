import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/core/theme/app_theme.dart';
import 'package:pixel_player/services/settings_service.dart';
import 'package:pixel_player/services/stream_cache_service.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';
import 'package:pixel_player/presentation/bloc/library/library_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/theme/theme_cubit.dart';
import 'package:pixel_player/presentation/screens/taste_profile_screen.dart';
import 'package:pixel_player/presentation/widgets/album_art_widget.dart';
import 'package:pixel_player/presentation/widgets/folder_picker_dialog.dart';
import 'package:pixel_player/services/user_taste_service.dart';
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
  late bool _showPlayerWaveform;
  late int _playerBackgroundPattern;
  late double _defaultVolume;

  // Download Settings State
  late String _downloadQuality;
  late String _downloadFormat;
  late bool _autoDownloadPlaylistMetadata;
  late bool _skipAlreadyDownloaded;
  late bool _downloadOnlyOnWifi;
  late double _maxSimultaneousDownloads;
  late bool _autoAddSharedSongs;

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

  // Streaming State
  late String _streamLanguage;
  late bool _autoDownloadStreamSongs;
  late bool _cacheStreamSongs;
  late int _streamCacheLimit;
  late bool _supportBannerEnabled;
  bool _isExportingCache = false;

  // Storage Stats (Real File System Calculation)
  double _musicSizeMb = 0.0;
  double _cacheSizeMb = 0.0;
  double _thumbnailsSizeMb = 0.0;
  bool _isLoadingStorageStats = true;

  final List<Color> _accentColors = AppTheme.accentColors;

  @override
  void initState() {
    super.initState();
    _settingsService = getIt<SettingsService>();
    _loadSettingsFromStorage();
    _loadStorageStats();
  }

  void _loadSettingsFromStorage() {
    _streamLanguage = _settingsService.streamLanguage;
    _autoDownloadStreamSongs = _settingsService.autoDownloadStreamSongs;
    _cacheStreamSongs = _settingsService.cacheStreamSongs;
    _streamCacheLimit = _settingsService.streamCacheLimit;
    _supportBannerEnabled = _settingsService.isSupportBannerEnabled;
    _autoPlayNext = _settingsService.autoPlayNext;
    _repeatMode = _settingsService.repeatMode;
    _shuffleByDefault = _settingsService.shuffleByDefault;
    _resumeLastSong = _settingsService.resumeLastSong;
    _showPlayerWaveform = _settingsService.showPlayerWaveform;
    _playerBackgroundPattern = _settingsService.playerBackgroundPattern;
    _defaultVolume = _settingsService.defaultVolume;

    _downloadQuality = _settingsService.downloadQuality;
    _downloadFormat = _settingsService.downloadFormat;
    _autoDownloadPlaylistMetadata = _settingsService.autoDownloadPlaylistMetadata;
    _skipAlreadyDownloaded = _settingsService.skipAlreadyDownloaded;
    _downloadOnlyOnWifi = _settingsService.downloadOnlyOnWifi;
    _maxSimultaneousDownloads = _settingsService.maxSimultaneousDownloads.toDouble();
    _autoAddSharedSongs = _settingsService.autoAddSharedSongs;

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
                  context.read<PlayerBloc>().add(SetAutoPlayNextEvent(val));
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
                      context.read<PlayerBloc>().add(SetRepeatModeEvent(val));
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
                  context.read<PlayerBloc>().add(SetShuffleEvent(val));
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
                    context.read<PlayerBloc>().add(SetVolumeEvent(val));
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

          // STREAMING & RECOMMENDATIONS SECTION
          _buildSectionHeader('Streaming & Recommendations'),
          _buildCardContainer(
            isDark: isDark,
            children: [
              ListTile(
                title: _tileTitle('Streaming Language'),
                subtitle: _tileSubtitle(
                  'Current: ${SettingsService.supportedStreamLanguages[_streamLanguage] ?? _streamLanguage}',
                ),
                trailing: DropdownButton<String>(
                  value: SettingsService.supportedStreamLanguages.containsKey(_streamLanguage)
                      ? _streamLanguage
                      : 'hindi',
                  underline: const SizedBox(),
                  dropdownColor: isDark ? const Color(0xFF232330) : Colors.white,
                  items: SettingsService.supportedStreamLanguages.entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: GoogleFonts.outfit()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _streamLanguage = val);
                      _settingsService.setStreamLanguage(val);
                      _showSnackBar('Streaming language set to ${SettingsService.supportedStreamLanguages[val]}');
                    }
                  },
                ),
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Streaming Quality'),
                subtitle: _tileSubtitle('High Definition 320 kbps AAC streaming via JioSaavn'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2BC5B4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2BC5B4), width: 0.8),
                  ),
                  child: const Text(
                    '320 kbps',
                    style: TextStyle(
                      color: Color(0xFF2BC5B4),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Auto-download Streamed Songs'),
                subtitle: _tileSubtitle('Automatically download online songs to device when played'),
                value: _autoDownloadStreamSongs,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _autoDownloadStreamSongs = val);
                  _settingsService.setAutoDownloadStreamSongs(val);
                },
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Cache Streamed Songs'),
                subtitle: _tileSubtitle('Automatically cache streamed songs for instant offline replay'),
                value: _cacheStreamSongs,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _cacheStreamSongs = val);
                  _settingsService.setCacheStreamSongs(val);
                },
              ),
              if (_cacheStreamSongs) ...[
                _divider(),
                ListTile(
                  title: _tileTitle('Stream Cache Limit'),
                  subtitle: _tileSubtitle('Maximum songs retained in offline cache (LRU eviction)'),
                  trailing: DropdownButton<int>(
                    value: [25, 50, 100, 200].contains(_streamCacheLimit)
                        ? _streamCacheLimit
                        : 50,
                    underline: const SizedBox(),
                    dropdownColor: isDark ? const Color(0xFF232330) : Colors.white,
                    items: const [
                      DropdownMenuItem(value: 25, child: Text('25 songs')),
                      DropdownMenuItem(value: 50, child: Text('50 songs (Default)')),
                      DropdownMenuItem(value: 100, child: Text('100 songs')),
                      DropdownMenuItem(value: 200, child: Text('200 songs')),
                    ].map((item) {
                      return DropdownMenuItem<int>(
                        value: item.value,
                        child: Text(
                          (item.child as Text).data!,
                          style: GoogleFonts.outfit(),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        setState(() => _streamCacheLimit = val);
                        await _settingsService.setStreamCacheLimit(val);
                        _loadStorageStats();
                        _showSnackBar('Stream cache limit set to $val songs');
                      }
                    },
                  ),
                ),
              ],
              _divider(),
              SwitchListTile(
                title: _tileTitle('GitHub Support Banner'),
                subtitle: _tileSubtitle(
                  _supportBannerEnabled
                      ? 'Show project support card in stream feed (after 5th launch)'
                      : 'Permanently hidden from stream feed',
                ),
                value: _supportBannerEnabled,
                activeThumbColor: _accentColor,
                onChanged: (val) async {
                  setState(() => _supportBannerEnabled = val);
                  await _settingsService.setSupportBannerEnabled(val);
                  _showSnackBar(val
                      ? 'GitHub support banner enabled'
                      : 'GitHub support banner permanently disabled');
                },
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Suggestion Songs & Artists'),
                subtitle: _tileSubtitle(
                  '${UserTasteService.instance.trackedSongCount} songs • ${UserTasteService.instance.trackedArtistCount} artists in recommendation profile',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TasteProfileScreen(),
                    ),
                  );
                  setState(() {});
                },
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
                  items: ['M4A', 'WebM'].map((f) {
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
              SwitchListTile(
                title: _tileTitle('Auto-add Shared Songs'),
                subtitle: _tileSubtitle(
                    'Automatically add songs received via Share to your library. When off, review and accept them from the download queue.'),
                value: _autoAddSharedSongs,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _autoAddSharedSongs = val);
                  _settingsService.setAutoAddSharedSongs(val);
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
                      context.read<ThemeCubit>().setThemeMode(val);
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: List.generate(_accentColors.length, (idx) {
                        final color = _accentColors[idx];
                        final isSelected = idx == _accentColorIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _accentColorIndex = idx;
                              _accentColor = color;
                            });
                            context.read<ThemeCubit>().setAccentColorIndex(idx);
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
                  context.read<ThemeCubit>().setAmoledBlackMode(val);
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
                      context.read<ThemeCubit>().setFontSize(val);
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
                      context.read<ThemeCubit>().setAlbumArtSize(val);
                    }
                  },
                ),
              ),
              _divider(),
              SwitchListTile(
                title: _tileTitle('Player Audio Waveform'),
                subtitle: _tileSubtitle('Show dynamic animated wave visualizer in player screen'),
                value: _showPlayerWaveform,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() => _showPlayerWaveform = val);
                  _settingsService.setShowPlayerWaveform(val);
                },
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Player Background Pattern'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tileSubtitle('Animated visual pattern behind the player'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        {'label': 'None', 'tag': ''},
                        {'label': 'Floating Orbs', 'tag': '✦ Live'},
                        {'label': 'Sound Waves', 'tag': '✦ Live'},
                        {'label': 'Geometric Grid', 'tag': '✦ Live'},
                        {'label': 'Aurora Glow', 'tag': '✦ Live'},
                        {'label': 'Honeycomb', 'tag': '◈ Static'},
                        {'label': 'Diagonal Stripes', 'tag': '◈ Static'},
                        {'label': 'Circuit Board', 'tag': '◈ Static'},
                        {'label': 'Starburst', 'tag': '◈ Static'},
                      ].asMap().entries.map((e) {
                        final isSelected = _playerBackgroundPattern == e.key;
                        final label = e.value['label'] as String;
                        final tag = e.value['tag'] as String;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _playerBackgroundPattern = e.key);
                            _settingsService.setPlayerBackgroundPattern(e.key);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _accentColor
                                  : _accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? _accentColor
                                    : _accentColor.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : null,
                                  ),
                                ),
                                if (tag.isNotEmpty)
                                  Text(
                                    tag,
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.75)
                                          : _accentColor.withValues(alpha: 0.6),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
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
                  if (val) {
                    context.read<LibraryBloc>().add(ScanStorageEvent(
                      ignoreShortAudio: _ignoreShortAudio,
                      showHiddenFiles: _showHiddenFiles,
                    ));
                  }
                },
              ),
              _divider(),
              ListTile(
                title: _tileTitle('Add Music Folder'),
                subtitle: _tileSubtitle('Select a specific folder to add its music to library'),
                trailing: const Icon(Icons.create_new_folder_rounded),
                onTap: () async {
                  final bloc = context.read<LibraryBloc>();
                  final selected = await showDialog<String>(
                    context: context,
                    builder: (_) => const FolderPickerDialog(),
                  );
                  if (selected != null && selected.isNotEmpty) {
                    bloc.add(ScanStorageEvent(
                      customPaths: [selected],
                      ignoreShortAudio: _ignoreShortAudio,
                      showHiddenFiles: _showHiddenFiles,
                    ));
                    if (mounted) {
                      _showSnackBar('Scanning folder: $selected');
                    }
                  }
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
                  context.read<LibraryBloc>().add(ScanStorageEvent(
                    ignoreShortAudio: val,
                    showHiddenFiles: _showHiddenFiles,
                  ));
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
                  context.read<LibraryBloc>().add(ScanStorageEvent(
                    ignoreShortAudio: _ignoreShortAudio,
                    showHiddenFiles: val,
                  ));
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
                onTap: () async {
                  await _settingsService.clearSearchHistory();
                  _showSnackBar('Search history cleared.');
                },
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _storageRow('Music Files', '${(_musicSizeMb / 1024).toStringAsFixed(2)} GB (${_musicSizeMb.toStringAsFixed(1)} MB)', Colors.blueAccent),
                        const SizedBox(height: 12),
                        _storageRow('App Cache', '${_cacheSizeMb.toStringAsFixed(1)} MB', Colors.orangeAccent),
                        const SizedBox(height: 12),
                        _storageRow(
                          'Stream Cache',
                          '${StreamCacheService.instance.cachedCount} / $_streamCacheLimit tracks (${StreamCacheService.instance.totalSizeMb.toStringAsFixed(1)} MB)',
                          const Color(0xFF2BC5B4),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_streamCacheLimit > 0)
                                ? (StreamCacheService.instance.cachedCount / _streamCacheLimit).clamp(0.0, 1.0)
                                : 0.0,
                            backgroundColor: isDark ? const Color(0xFF2A2A38) : const Color(0xFFE5E5EB),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              (StreamCacheService.instance.cachedCount >= _streamCacheLimit)
                                  ? Colors.amberAccent
                                  : const Color(0xFF2BC5B4),
                            ),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _storageRow('Thumbnails', '${_thumbnailsSizeMb.toStringAsFixed(1)} MB', Colors.purpleAccent),
                        const SizedBox(height: 20),
                        // 1. Export cached songs to Library
                        ElevatedButton.icon(
                          icon: _isExportingCache
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.library_add_check_rounded, size: 18),
                          label: Text(
                            _isExportingCache ? 'Exporting to Library...' : 'Export Cached Songs to Library',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isExportingCache
                              ? null
                              : () async {
                                  if (StreamCacheService.instance.cachedCount == 0) {
                                    _showSnackBar('No cached stream songs available to export.');
                                    return;
                                  }
                                  setState(() => _isExportingCache = true);
                                  try {
                                    final count = await StreamCacheService.instance.exportCachedSongsToLibrary();
                                    if (context.mounted) {
                                      context.read<LibraryBloc>().add(const LoadLibraryEvent());
                                    }
                                    if (mounted) {
                                      _showSnackBar(count > 0
                                          ? 'Successfully exported $count songs to your Music Library!'
                                          : 'All cached songs are already in your Library.');
                                      _loadStorageStats();
                                    }
                                  } catch (e) {
                                    _showSnackBar('Export failed: $e');
                                  } finally {
                                    if (mounted) setState(() => _isExportingCache = false);
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        // 2. View Cached Songs & Clear Stream Cache
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.queue_music_rounded, size: 18, color: Color(0xFF2BC5B4)),
                                label: Text(
                                  'View Tracks',
                                  style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: BorderSide(color: const Color(0xFF2BC5B4).withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _showCachedSongsSheet(isDark),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.music_off_outlined, size: 18, color: Colors.orangeAccent),
                                label: Text(
                                  'Clear Stream',
                                  style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () async {
                                  await _settingsService.clearStreamCache();
                                  _showSnackBar('Stream cache cleared!');
                                  _loadStorageStats();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 3. Clear App Cache & Clear Art
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

  void _showCachedSongsSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final entries = StreamCacheService.instance.entries;
            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Offline Stream Cache',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${entries.length} / $_streamCacheLimit songs • ${StreamCacheService.instance.totalSizeMb.toStringAsFixed(1)} MB',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          if (entries.isNotEmpty)
                            TextButton.icon(
                              icon: const Icon(Icons.cleaning_services_rounded, size: 16, color: Colors.redAccent),
                              label: Text('Clear All', style: GoogleFonts.outfit(color: Colors.redAccent)),
                              onPressed: () async {
                                await _settingsService.clearStreamCache();
                                setSheetState(() {});
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (mounted) {
                                _loadStorageStats();
                                _showSnackBar('Stream cache cleared.');
                              }
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    Expanded(
                      child: entries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.music_off_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No cached stream songs',
                                    style: GoogleFonts.outfit(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: entries.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                final sizeMb = (entry.sizeBytes / 1024 / 1024).toStringAsFixed(1);
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: AlbumArtWidget(
                                      albumArt: entry.albumArt,
                                      width: 48,
                                      height: 48,
                                    ),
                                  ),
                                  title: Text(
                                    entry.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    '${entry.artist} • $sizeMb MB',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                                    tooltip: 'Delete track from cache',
                                    onPressed: () async {
                                      await StreamCacheService.instance.removeCachedSong(entry.songId);
                                      setSheetState(() {});
                                      _loadStorageStats();
                                    },
                                  ),
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
}
