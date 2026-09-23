import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:on_audio_query/on_audio_query.dart';

class AlbumArtWidget extends StatefulWidget {
  final String? albumArt;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final bool isCircular;
  final IconData fallbackIcon;
  final double? iconSize;
  final Color? fallbackBgColor;
  final Color? fallbackIconColor;

  const AlbumArtWidget({
    super.key,
    required this.albumArt,
    required this.width,
    required this.height,
    this.borderRadius,
    this.isCircular = false,
    this.fallbackIcon = Icons.music_note_rounded,
    this.iconSize,
    this.fallbackBgColor,
    this.fallbackIconColor,
  });

  @override
  State<AlbumArtWidget> createState() => _AlbumArtWidgetState();
}

class _AlbumArtWidgetState extends State<AlbumArtWidget> {
  // Global memory cache to prevent re-querying MediaStore on widget rebuilds.
  static final Map<String, Uint8List?> _artCache = <String, Uint8List?>{};
  static final Map<String, Future<Uint8List?>> _inFlight =
      <String, Future<Uint8List?>>{};
  static const int _maxCacheEntries = 600;

  Uint8List? _bytes;
  String? _resolvedKey;

  @override
  void initState() {
    super.initState();
    _resolveArtwork();
  }

  @override
  void didUpdateWidget(AlbumArtWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumArt != widget.albumArt) {
      _resolveArtwork();
    }
  }

  void _resolveArtwork() {
    final art = widget.albumArt?.trim();
    if (art == null || art.isEmpty || !art.startsWith('mediastore://')) {
      _bytes = null;
      _resolvedKey = null;
      return;
    }

    final key = _getCacheKey(art);
    _resolvedKey = key;

    // If already in memory cache, load synchronously with ZERO delay/flicker.
    if (_artCache.containsKey(key)) {
      _bytes = _artCache[key];
      return;
    }

    _bytes = null;
    _fetchArtwork(art, key).then((data) {
      if (mounted && _resolvedKey == key) {
        setState(() {
          _bytes = data;
        });
      }
    });
  }

  static String _getCacheKey(String path) {
    int? audioId;
    int? albumId;

    if (path.contains('audio:')) {
      final match = RegExp(r'audio:(\d+)').firstMatch(path);
      if (match != null) audioId = int.tryParse(match.group(1)!);
    }
    if (path.contains('album:')) {
      final match = RegExp(r'album:(\d+)').firstMatch(path);
      if (match != null) albumId = int.tryParse(match.group(1)!);
    }
    if (audioId == null && albumId == null) {
      audioId = int.tryParse(path.replaceFirst('mediastore://', ''));
    }

    return 'art_audio_${audioId}_album_$albumId';
  }

  static Future<Uint8List?> _fetchArtwork(String path, String key) {
    if (_artCache.containsKey(key)) {
      return Future.value(_artCache[key]);
    }
    if (_inFlight.containsKey(key)) {
      return _inFlight[key]!;
    }

    final future = _loadFromMediaStore(path);
    _inFlight[key] = future;

    future.then((bytes) {
      _inFlight.remove(key);
      if (_artCache.length >= _maxCacheEntries) {
        _artCache.remove(_artCache.keys.first);
      }
      _artCache[key] = bytes;
    }).catchError((_) {
      _inFlight.remove(key);
      _artCache[key] = null;
    });

    return future;
  }

  static Future<Uint8List?> _loadFromMediaStore(String path) async {
    try {
      int? audioId;
      int? albumId;

      if (path.contains('audio:')) {
        final match = RegExp(r'audio:(\d+)').firstMatch(path);
        if (match != null) audioId = int.tryParse(match.group(1)!);
      }
      if (path.contains('album:')) {
        final match = RegExp(r'album:(\d+)').firstMatch(path);
        if (match != null) albumId = int.tryParse(match.group(1)!);
      }
      if (audioId == null && albumId == null) {
        audioId = int.tryParse(path.replaceFirst('mediastore://', ''));
      }

      final onAudioQuery = OnAudioQuery();
      Uint8List? bytes;

      if (audioId != null) {
        bytes = await onAudioQuery.queryArtwork(
          audioId,
          ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          size: 400,
          quality: 85,
        );
      }

      if ((bytes == null || bytes.isEmpty) && albumId != null) {
        bytes = await onAudioQuery.queryArtwork(
          albumId,
          ArtworkType.ALBUM,
          format: ArtworkFormat.JPEG,
          size: 400,
          quality: 85,
        );
      }

      if (bytes != null && bytes.isNotEmpty) {
        return bytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bgColor =
        widget.fallbackBgColor ?? theme.colorScheme.primaryContainer;

    final iconColor =
        widget.fallbackIconColor ?? theme.colorScheme.onPrimaryContainer;

    final effectiveIconSize =
        widget.iconSize ?? (widget.width * 0.45).clamp(16.0, 140.0);

    final Widget placeholder = Container(
      width: widget.width,
      height: widget.height,
      color: bgColor,
      child: Center(
        child: Icon(
          widget.fallbackIcon,
          size: effectiveIconSize,
          color: iconColor,
        ),
      ),
    );

    Widget content = placeholder;

    if (widget.albumArt != null && widget.albumArt!.trim().isNotEmpty) {
      final path = widget.albumArt!.trim();

      // Network image
      if (path.startsWith('http://') || path.startsWith('https://')) {
        content = CachedNetworkImage(
          imageUrl: path,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (_, __) => placeholder,
          errorWidget: (_, __, ___) => placeholder,
        );
      }

      // Android MediaStore artwork
      else if (path.startsWith('mediastore://')) {
        if (_bytes != null && _bytes!.isNotEmpty) {
          content = Image.memory(
            _bytes!,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => placeholder,
          );
        } else {
          content = placeholder;
        }
      }

      // Local image file
      else {
        final cleanPath = path.startsWith('file://')
            ? Uri.parse(path).toFilePath()
            : path;
        final file = File(cleanPath);

        if (file.existsSync()) {
          content = Image.file(
            file,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => placeholder,
          );
        }
      }
    }

    if (widget.isCircular) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipOval(child: content),
      );
    }

    if (widget.borderRadius != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius: widget.borderRadius!,
          child: content,
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: content,
    );
  }
}