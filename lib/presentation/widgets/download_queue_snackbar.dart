import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows queue feedback using the active app color scheme instead of the
/// platform-default snackbar styling.
void showDownloadQueuedSnackBar(
  BuildContext context, {
  required String title,
  VoidCallback? onViewQueue,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final theme = Theme.of(context);
  final colors = theme.colorScheme;

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      dismissDirection: DismissDirection.horizontal,
      elevation: 4,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.zero,
      backgroundColor: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.download_rounded,
                color: colors.onPrimaryContainer,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Added to download queue',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      action: onViewQueue == null
          ? null
          : SnackBarAction(
              label: 'QUEUE',
              textColor: colors.primary,
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onViewQueue();
              },
            ),
    ),
  );
}
