import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/services/download_service.dart';
import 'package:pixel_player/presentation/widgets/download_queue_sheet.dart';
import 'package:pixel_player/presentation/widgets/download_queue_snackbar.dart';

class DownloadDialog extends StatefulWidget {
  final String? initialUrl;
  final BuildContext parentContext;

  const DownloadDialog({
    super.key,
    this.initialUrl,
    required this.parentContext,
  });

  static Future<void> show(BuildContext context, {String? initialUrl}) async {
    final parentCtx = context;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: DownloadDialog(
          initialUrl: initialUrl,
          parentContext: parentCtx,
        ),
      ),
    );
  }

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  late final TextEditingController _urlController;
  late final DownloadService _downloadService;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _downloadService = getIt<DownloadService>();

    if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _enqueueAndClose();
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _enqueueAndClose() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter or paste a valid link.';
      });
      return;
    }

    _downloadService.enqueueDownload(url: url);

    final parentCtx = widget.parentContext;
    Navigator.pop(context);

    if (parentCtx.mounted) {
      showDownloadQueuedSnackBar(
        parentCtx,
        title: url,
        onViewQueue: () {
          if (parentCtx.mounted) {
            DownloadQueueSheet.show(parentCtx);
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔝 Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.cloud_download_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download Audio from Link',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'YouTube, Direct MP3, SoundCloud & Shared Links',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _urlController,
            onSubmitted: (_) => _enqueueAndClose(),
            decoration: InputDecoration(
              hintText: 'Paste YouTube or MP3 URL here...',
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data != null && data.text != null) {
                    _urlController.text = data.text!;
                  }
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'Add to Queue',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                onPressed: _enqueueAndClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
