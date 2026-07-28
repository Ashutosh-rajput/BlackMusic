import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    final bgColor = fallbackBgColor ?? theme.colorScheme.primaryContainer;
    final iconColor = fallbackIconColor ?? theme.colorScheme.onPrimaryContainer;
    final effectiveIconSize = iconSize ?? (width * 0.45).clamp(16.0, 140.0);

    final Widget placeholder = Container(
      width: width,
      height: height,
      color: bgColor,
      child: Center(
        child: Icon(
          fallbackIcon,
          color: iconColor,
          size: effectiveIconSize,
        ),
      ),
    );

    Widget content = placeholder;

    if (albumArt != null && albumArt!.trim().isNotEmpty) {
      final path = albumArt!.trim();
      if (path.startsWith('http://') || path.startsWith('https://')) {
        content = CachedNetworkImage(
          imageUrl: path,
          width: width,
          height: height,
          fit: BoxFit.cover,
          placeholder: (ctx, url) => placeholder,
          errorWidget: (ctx, url, err) => placeholder,
        );
      } else {
        final file = File(path);
        if (file.existsSync()) {
          content = Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => placeholder,
          );
        }
      }
    }

    if (isCircular) {
      return ClipOval(child: content);
    } else if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
