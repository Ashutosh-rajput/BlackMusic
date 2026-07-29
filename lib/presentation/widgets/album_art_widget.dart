import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:on_audio_query/on_audio_query.dart';

class AlbumArtWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bgColor =
        fallbackBgColor ?? theme.colorScheme.primaryContainer;

    final iconColor =
        fallbackIconColor ?? theme.colorScheme.onPrimaryContainer;

    final effectiveIconSize =
        iconSize ?? (width * 0.45).clamp(16.0, 140.0);

    final Widget placeholder = Container(
      width: width,
      height: height,
      color: bgColor,
      child: Center(
        child: Icon(
          fallbackIcon,
          size: effectiveIconSize,
          color: iconColor,
        ),
      ),
    );

    Widget content = placeholder;

    if (albumArt != null && albumArt!.trim().isNotEmpty) {
      final path = albumArt!.trim();

      // Network image
      if (path.startsWith('http://') ||
          path.startsWith('https://')) {
        content = CachedNetworkImage(
          imageUrl: path,
          width: width,
          height: height,
          fit: BoxFit.cover,
          placeholder: (_, __) => placeholder,
          errorWidget: (_, __, ___) => placeholder,
        );
      }

      // Android MediaStore artwork
      else if (path.startsWith('mediastore://')) {
        final id =
            int.tryParse(path.replaceFirst('mediastore://', ''));

        if (id != null) {
          content = QueryArtworkWidget(
            id: id,
            type: ArtworkType.AUDIO,
            artworkFit: BoxFit.cover,
            artworkWidth: width,
            artworkHeight: height,
            format: ArtworkFormat.JPEG,
            size: (width * 2).toInt().clamp(150, 800),
            nullArtworkWidget: placeholder,
            errorBuilder: (_, __, ___) => placeholder,
          );
        }
      }

      // Local image file
      else {
        final file = File(path);

        if (file.existsSync()) {
          content = Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          );
        }
      }
    }

    if (isCircular) {
      return SizedBox(
        width: width,
        height: height,
        child: ClipOval(child: content),
      );
    }

    if (borderRadius != null) {
      return SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: borderRadius!,
          child: content,
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: content,
    );
  }
}