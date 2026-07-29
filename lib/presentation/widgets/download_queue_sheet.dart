import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/services/download_service.dart';
import 'package:pixel_player/presentation/widgets/download_queue_snackbar.dart';

class DownloadQueueSheet extends StatefulWidget {
  const DownloadQueueSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const DownloadQueueSheet(),
      ),
    );
  }

  @override
  State<DownloadQueueSheet> createState() => _DownloadQueueSheetState();
}

class _DownloadQueueSheetState extends State<DownloadQueueSheet> {
  final TextEditingController _urlController = TextEditingController();
  final DownloadService _downloadService = getIt<DownloadService>();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _addLinkToQueue() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      _downloadService.enqueueDownload(url: url);
      _urlController.clear();
      showDownloadQueuedSnackBar(
        context,
        title: 'Link added to queue',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.downloading_rounded, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Download Queue',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ValueListenableBuilder<List<ActiveDownload>>(
                  valueListenable: _downloadService.downloadQueueNotifier,
                  builder: (context, queue, _) {
                    final hasActive = queue.any(
                        (d) => d.status == DownloadStatus.queued || d.status == DownloadStatus.downloading);
                    final hasFinished = queue.any(
                        (d) => d.isCompleted || d.isCancelled || d.isFailed);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasActive)
                          TextButton(
                            onPressed: () {
                              _downloadService.cancelAllDownloads();
                            },
                            child: Text('Cancel All',
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: Colors.redAccent)),
                          ),
                        if (hasFinished)
                          TextButton(
                            onPressed: () {
                              _downloadService.clearCompletedDownloads();
                            },
                            child: Text('Clear Finished',
                                style: GoogleFonts.outfit(fontSize: 12)),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Add URL Input Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    onSubmitted: (_) => _addLinkToQueue(),
                    decoration: InputDecoration(
                      hintText: 'Paste YouTube / MP3 link to queue...',
                      prefixIcon: const Icon(Icons.link_rounded),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2B2B38)
                          : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Add pasted link to the download queue',
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('Add', style: GoogleFonts.outfit()),
                    onPressed: _addLinkToQueue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // Download List
          Expanded(
            child: ValueListenableBuilder<List<ActiveDownload>>(
              valueListenable: _downloadService.downloadQueueNotifier,
              builder: (context, queue, _) {
                if (queue.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No downloads in queue',
                          style: GoogleFonts.outfit(
                              fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: queue.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    return _QueueItemTile(item: item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueItemTile extends StatelessWidget {
  final ActiveDownload item;

  const _QueueItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget statusIcon;
    Color statusColor;

    if (item.isCompleted) {
      statusIcon =
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24);
      statusColor = Colors.green;
    } else if (item.isDownloading) {
      statusIcon = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
      statusColor = theme.colorScheme.primary;
    } else if (item.isQueued) {
      statusIcon =
          const Icon(Icons.schedule_rounded, color: Colors.orange, size: 24);
      statusColor = Colors.orange;
    } else if (item.isFailed) {
      statusIcon =
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24);
      statusColor = Colors.red;
    } else {
      statusIcon =
          const Icon(Icons.cancel_outlined, color: Colors.grey, size: 24);
      statusColor = Colors.grey;
    }

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF262634) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                statusIcon,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        item.statusMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: statusColor),
                      ),
                    ],
                  ),
                ),
                if (item.isDownloading || item.isQueued)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Cancel',
                    onPressed: () {
                      getIt<DownloadService>().cancelDownloadByUrl(item.url);
                    },
                  )
                else if (item.isFailed || item.isCancelled)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Retry Download',
                    onPressed: () {
                      getIt<DownloadService>().enqueueDownload(
                        url: item.url,
                        title: item.title,
                      );
                    },
                  ),
              ],
            ),
            if (item.isDownloading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progress > 0 ? item.progress : null,
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
