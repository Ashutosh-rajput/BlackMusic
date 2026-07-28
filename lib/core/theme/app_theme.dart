import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const List<Color> accentColors = [
    Color(0xFF8E44AD), // Deep Purple
    Color(0xFF00E676), // Vibrant Mint Green
    Color(0xFFFF5722), // Vibrant Orange
    Color(0xFF29B6F6), // Sky Blue
    Color(0xFFEC407A), // Hot Pink
    Color(0xFFFFC107), // Amber Gold
  ];

  static const Color darkBackground = Color(0xFF121216);
  static const Color amoledBackground = Color(0xFF000000);
  static const Color darkCard = Color(0xFF262630);
  static const Color amoledCard = Color(0xFF141418);

  static ThemeData buildTheme({
    required Brightness brightness,
    int accentIndex = 0,
    bool isAmoled = false,
    String fontSize = 'Medium',
  }) {
    final isDark = brightness == Brightness.dark;
    final safeIndex = accentIndex.clamp(0, accentColors.length - 1);
    final accent = accentColors[safeIndex];

    final bgColor = isDark
        ? (isAmoled ? amoledBackground : darkBackground)
        : const Color(0xFFF4F5F7);
    final cardColor = isDark
        ? (isAmoled ? amoledCard : darkCard)
        : Colors.white;

    final baseScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: accent,
      secondary: accent,
      surface: bgColor,
    );

    double fontScale = 1.0;
    if (fontSize == 'Small') fontScale = 0.9;
    if (fontSize == 'Large') fontScale = 1.1;

    final rawTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final outfitTheme = GoogleFonts.outfitTextTheme(rawTextTheme);

    // Safely scale only styles that already have a fontSize defined
    TextTheme textTheme = outfitTheme;
    if (fontScale != 1.0) {
      textTheme = outfitTheme.copyWith(
        displayLarge: outfitTheme.displayLarge?.fontSize != null
            ? outfitTheme.displayLarge!.copyWith(fontSize: outfitTheme.displayLarge!.fontSize! * fontScale) : outfitTheme.displayLarge,
        displayMedium: outfitTheme.displayMedium?.fontSize != null
            ? outfitTheme.displayMedium!.copyWith(fontSize: outfitTheme.displayMedium!.fontSize! * fontScale) : outfitTheme.displayMedium,
        displaySmall: outfitTheme.displaySmall?.fontSize != null
            ? outfitTheme.displaySmall!.copyWith(fontSize: outfitTheme.displaySmall!.fontSize! * fontScale) : outfitTheme.displaySmall,
        headlineLarge: outfitTheme.headlineLarge?.fontSize != null
            ? outfitTheme.headlineLarge!.copyWith(fontSize: outfitTheme.headlineLarge!.fontSize! * fontScale) : outfitTheme.headlineLarge,
        headlineMedium: outfitTheme.headlineMedium?.fontSize != null
            ? outfitTheme.headlineMedium!.copyWith(fontSize: outfitTheme.headlineMedium!.fontSize! * fontScale) : outfitTheme.headlineMedium,
        headlineSmall: outfitTheme.headlineSmall?.fontSize != null
            ? outfitTheme.headlineSmall!.copyWith(fontSize: outfitTheme.headlineSmall!.fontSize! * fontScale) : outfitTheme.headlineSmall,
        titleLarge: outfitTheme.titleLarge?.fontSize != null
            ? outfitTheme.titleLarge!.copyWith(fontSize: outfitTheme.titleLarge!.fontSize! * fontScale) : outfitTheme.titleLarge,
        titleMedium: outfitTheme.titleMedium?.fontSize != null
            ? outfitTheme.titleMedium!.copyWith(fontSize: outfitTheme.titleMedium!.fontSize! * fontScale) : outfitTheme.titleMedium,
        titleSmall: outfitTheme.titleSmall?.fontSize != null
            ? outfitTheme.titleSmall!.copyWith(fontSize: outfitTheme.titleSmall!.fontSize! * fontScale) : outfitTheme.titleSmall,
        bodyLarge: outfitTheme.bodyLarge?.fontSize != null
            ? outfitTheme.bodyLarge!.copyWith(fontSize: outfitTheme.bodyLarge!.fontSize! * fontScale) : outfitTheme.bodyLarge,
        bodyMedium: outfitTheme.bodyMedium?.fontSize != null
            ? outfitTheme.bodyMedium!.copyWith(fontSize: outfitTheme.bodyMedium!.fontSize! * fontScale) : outfitTheme.bodyMedium,
        bodySmall: outfitTheme.bodySmall?.fontSize != null
            ? outfitTheme.bodySmall!.copyWith(fontSize: outfitTheme.bodySmall!.fontSize! * fontScale) : outfitTheme.bodySmall,
        labelLarge: outfitTheme.labelLarge?.fontSize != null
            ? outfitTheme.labelLarge!.copyWith(fontSize: outfitTheme.labelLarge!.fontSize! * fontScale) : outfitTheme.labelLarge,
        labelMedium: outfitTheme.labelMedium?.fontSize != null
            ? outfitTheme.labelMedium!.copyWith(fontSize: outfitTheme.labelMedium!.fontSize! * fontScale) : outfitTheme.labelMedium,
        labelSmall: outfitTheme.labelSmall?.fontSize != null
            ? outfitTheme.labelSmall!.copyWith(fontSize: outfitTheme.labelSmall!.fontSize! * fontScale) : outfitTheme.labelSmall,
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: bgColor,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: cardColor,
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
          fontSize: 20 * fontScale,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.black,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
    );
  }
}

final darkTheme = AppTheme.buildTheme(brightness: Brightness.dark);
final lightTheme = AppTheme.buildTheme(brightness: Brightness.light);
