import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/services/audio_service.dart';
import 'package:pixel_player/services/sleep_timer_service.dart';

class SleepTimerDialog extends StatelessWidget {
  const SleepTimerDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const SleepTimerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timerService = SleepTimerService();

    return ListenableBuilder(
      listenable: timerService,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sleep Timer',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (timerService.isActive)
                    TextButton(
                      onPressed: () {
                        timerService.cancelTimer();
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Turn Off',
                        style: GoogleFonts.outfit(color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
              if (timerService.isActive) ...[
                const SizedBox(height: 8),
                Text(
                  'Timer active: ${_formatRemaining(timerService.remainingTime)}',
                  style: GoogleFonts.outfit(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildOptionTile(
                context,
                title: '15 Minutes',
                mode: SleepTimerMode.minutes15,
                currentMode: timerService.mode,
              ),
              _buildOptionTile(
                context,
                title: '30 Minutes',
                mode: SleepTimerMode.minutes30,
                currentMode: timerService.mode,
              ),
              _buildOptionTile(
                context,
                title: '45 Minutes',
                mode: SleepTimerMode.minutes45,
                currentMode: timerService.mode,
              ),
              _buildOptionTile(
                context,
                title: '60 Minutes',
                mode: SleepTimerMode.minutes60,
                currentMode: timerService.mode,
              ),
              _buildOptionTile(
                context,
                title: 'End of Current Song',
                mode: SleepTimerMode.endOfSong,
                currentMode: timerService.mode,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required String title,
    required SleepTimerMode mode,
    required SleepTimerMode currentMode,
  }) {
    final isSelected = mode == currentMode;
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        final audioService = getIt<AudioPlayerService>();
        SleepTimerService().startTimer(mode, audioService: audioService);
        Navigator.pop(context);
      },
    );
  }

  String _formatRemaining(Duration duration) {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
