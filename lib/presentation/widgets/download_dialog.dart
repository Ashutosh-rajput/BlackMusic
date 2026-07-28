import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';
import 'package:pixel_player/presentation/bloc/library/library_event.dart';
import 'package:pixel_player/services/download_service.dart';

class DownloadDialog extends StatefulWidget {
  final String? initialUrl;

  const DownloadDialog({super.key, this.initialUrl});

  static Future<void> show(BuildContext context, {String? initialUrl}) async {
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
        child: DownloadDialog(initialUrl: initialUrl),
      ),
    );
  }

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  late final TextEditingController _urlController;
  late final DownloadService _downloadService;

  bool _isDownloading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _downloadService = getIt<DownloadService>();

    final active = _downloadService.activeDownloadNotifier.value;
    if (active != null && !active.isCompleted && !active.isCancelled && active.errorMessage == null) {
      _isDownloading = true;
      _urlController.text = active.url;
    } else if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startDownload();
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter or paste a valid link.';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final song = await _downloadService.downloadFromUrl(
        url: url,
        onProgress: (p, status) {},
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        context.read<LibraryBloc>().add(const LoadLibraryEvent());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              song != null
                  ? 'Successfully downloaded "${song.title}"!'
                  : 'Download complete! Library updated.',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<ActiveDownload?>(
      valueListenable: _downloadService.activeDownloadNotifier,
      builder: (context, activeDownload, _) {
        final isRunning = _isDownloading ||
            (activeDownload != null &&
                !activeDownload.isCompleted &&
                !activeDownload.isCancelled &&
                activeDownload.errorMessage == null);

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔝 Collapsible Drag Handle Line
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
                enabled: !isRunning,
                decoration: InputDecoration(
                  hintText: 'Paste YouTube or MP3 URL here...',
                  prefixIcon: const Icon(Icons.link_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: isRunning
                        ? null
                        : () async {
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
              if (_errorMessage != null || activeDownload?.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? activeDownload!.errorMessage!,
                  style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              if (isRunning) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: activeDownload?.progress ?? 0.0,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 8,
                ),
                const SizedBox(height: 10),
                Text(
                  activeDownload?.statusMessage ?? 'Initializing download...',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      if (isRunning) {
                        _downloadService.cancelCurrentDownload();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      isRunning ? 'Cancel Download' : 'Close',
                      style: GoogleFonts.outfit(
                        color: isRunning ? Colors.redAccent : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    icon: isRunning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(isRunning ? 'Downloading...' : 'Download'),
                    onPressed: isRunning ? null : _startDownload,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
