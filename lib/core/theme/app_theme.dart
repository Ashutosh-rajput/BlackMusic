import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primarySeed = Color(0xFF8E44AD); // Deep Violet / Purple Accent
  static const Color accentColor = Color(0xFF00E676);  // Vibrant Mint Green
  static const Color darkBackground = Color(0xFF121216); // Ultra Dark Charcoal
  static const Color darkSurface = Color(0xFF1E1E24);
  static const Color darkCard = Color(0xFF262630);

  static ThemeData buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: brightness,
      primary: isDark ? const Color(0xFFBB86FC) : primarySeed,
      secondary: accentColor,
      surface: isDark ? darkBackground : const Color(0xFFF8F9FA),
    );

    final textTheme = GoogleFonts.outfitTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: isDark ? darkBackground : const Color(0xFFF4F5F7),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: isDark ? darkCard : Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.black,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: isDark ? baseScheme.primary : primarySeed,
        inactiveTrackColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
        thumbColor: isDark ? baseScheme.primary : primarySeed,
        overlayColor: (isDark ? baseScheme.primary : primarySeed).withValues(alpha: 0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
    );
  }
}

final darkTheme = AppTheme.buildTheme(Brightness.dark);
final lightTheme = AppTheme.buildTheme(Brightness.light);
