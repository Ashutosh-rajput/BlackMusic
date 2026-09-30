import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinyl/core/di/injection_container.dart';
import 'package:vinyl/services/settings_service.dart';

/// One-time onboarding / intro sheet introducing Vinyl as a hybrid
/// player, downloader, and stream app with smart caching.
class WelcomeIntroSheet extends StatelessWidget {
  const WelcomeIntroSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final settings = getIt<SettingsService>();
    if (settings.hasSeenAppIntro) return;

    // Mark as seen so it will never show again
    await settings.setHasSeenAppIntro(true);

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const WelcomeIntroSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Glowing App Icon
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                      Colors.deepPurpleAccent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.album_rounded,
                  size: 34,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),

              // Title & Subtitle
              Text(
                'Welcome to Vinyl',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your Hybrid Music Player • Downloader • Streamer',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 18),

              // 1. Local Music Player Feature Card
              _buildFeatureTile(
                context: context,
                icon: Icons.library_music_rounded,
                iconColor: Colors.blueAccent,
                title: 'Offline Music Player',
                description:
                    'Scan, import, and play all the songs stored on your device with custom playlists, and full equalizer control.',
              ),
              const SizedBox(height: 10),

              // 2. Music Downloader Feature Card
              _buildFeatureTile(
                context: context,
                icon: Icons.download_for_offline_rounded,
                iconColor: Colors.greenAccent,
                title: 'High-Quality Downloader',
                description:
                    'Search or explore Top Downloads from YouTube and JioSaavn to download 320kbps tracks permanently into your offline library.',
              ),
              const SizedBox(height: 10),

              // 3. Stream & Smart Offline Cache Feature Card
              _buildFeatureTile(
                context: context,
                icon: Icons.podcasts_rounded,
                iconColor: Colors.orangeAccent,
                title: 'Stream & 50-Song Offline Cache',
                description:
                    'Stream millions of songs on demand. Since live stream providers can occasionally experience downtime, downloading favorites is always recommended. But even while streaming, Vinyl automatically caches up to 50 songs so you can play them offline without internet!',
              ),
              const SizedBox(height: 22),

              // CTA Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    height: 1.35,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
