import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_event.dart';
import 'package:pixel_player/presentation/bloc/player/player_state.dart';

class QueueBottomSheet extends StatelessWidget {
  const QueueBottomSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const QueueBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BlocBuilder<PlayerBloc, PlayerState>(
        buildWhen: (previous, current) {
          if (previous.runtimeType != current.runtimeType) return true;
          if (previous is PlayerPlaying && current is PlayerPlaying) {
            return previous.song.id != current.song.id ||
                previous.queue != current.queue;
          }
          if (previous is PlayerPaused && current is PlayerPaused) {
            return previous.song.id != current.song.id ||
                previous.queue != current.queue;
          }
          return true;
        },
        builder: (context, state) {
          List<Song> queue = [];
          Song? currentSong;

          if (state is PlayerPlaying) {
            queue = state.queue;
            currentSong = state.song;
          } else if (state is PlayerPaused) {
            queue = state.queue;
            currentSong = state.song;
          }

          return Column(
            children: [
              // Top Drag Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Queue Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Playback Queue',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${queue.length} tracks in queue',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    if (queue.length > 1)
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all_rounded, size: 18),
                        label: Text('Clear', style: GoogleFonts.outfit(fontSize: 13)),
                        onPressed: () {
                          context.read<PlayerBloc>().add(const ClearQueueEvent());
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Queue List
              Expanded(
                child: queue.isEmpty
                    ? Center(
                        child: Text(
                          'Queue is empty',
                          style: GoogleFonts.outfit(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: queue.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIndex, newIndex) {
                          context.read<PlayerBloc>().add(
                                ReorderQueueEvent(oldIndex, newIndex),
                              );
                        },
                        itemBuilder: (context, index) {
                          if (index < 0 || index >= queue.length) {
                            return const SizedBox.shrink(key: ValueKey('empty_queue_guard'));
                          }
                          final song = queue[index];
                          final isCurrent = currentSong?.id == song.id;

                          return Material(
                            key: ValueKey('queue_item_${song.id}'),
                            color: isCurrent
                                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                                : Colors.transparent,
                            child: ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: isCurrent
                                      ? Icon(
                                          Icons.graphic_eq_rounded,
                                          color: theme.colorScheme.primary,
                                        )
                                      : Text(
                                          '${index + 1}',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                ),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  color: isCurrent ? theme.colorScheme.primary : null,
                                ),
                              ),
                              subtitle: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 20),
                                    onPressed: () {
                                      context.read<PlayerBloc>().add(
                                            RemoveFromQueueEvent(index),
                                          );
                                    },
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(Icons.drag_handle_rounded),
                                  ),
                                ],
                              ),
                              onTap: () {
                                context.read<PlayerBloc>().add(
                                      PlaySongAtIndexEvent(index),
                                    );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
