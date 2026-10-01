import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vinyl/services/update_service.dart';

/// "New version available" popup. Update opens the GitHub release page.
class UpdateDialog extends StatelessWidget {
  final AppUpdate update;

  const UpdateDialog({super.key, required this.update});

  /// Checks for a newer release and, if there is one, shows the popup.
  /// Silent when up to date or offline.
  static Future<void> checkAndShow(BuildContext context) async {
    final update = await UpdateService.checkForUpdate();
    if (update == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => UpdateDialog(update: update),
    );
  }

  Future<void> _openRelease() async {
    // The repository's main page, not the individual release page.
    final uri = Uri.parse(UpdateService.repoUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = update.notes.length > 600 ? '${update.notes.substring(0, 600)}…' : update.notes;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.system_update_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'New version available',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vinyl ${update.version} is out.',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  "What's new",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(notes, style: GoogleFonts.outfit(fontSize: 13, height: 1.4)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            UpdateService.skipVersion(update.version);
            Navigator.pop(context);
          },
          child: Text('Skip this version', style: GoogleFonts.outfit()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Later', style: GoogleFonts.outfit()),
        ),
        FilledButton(
          onPressed: () {
            _openRelease();
            Navigator.pop(context);
          },
          child: Text('Update', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
