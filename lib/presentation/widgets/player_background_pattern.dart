import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Background pattern widget for the player screen.
/// Patterns 1–4 are animated. Patterns 5–8 are static.
/// [patternIndex] 0=None, 1=Floating Orbs, 2=Sound Waves, 3=Geometric Grid,
///               4=Aurora Glow, 5=Honeycomb, 6=Diagonal Stripes,
///               7=Circuit Board, 8=Starburst
class PlayerBackgroundPattern extends StatelessWidget {
  final int patternIndex;
  final Animation<double> animation;
  final Color accentColor;

  const PlayerBackgroundPattern({
    super.key,
    required this.patternIndex,
    required this.animation,
    required this.accentColor,
  });

  static const List<String> patternNames = [
    'None',
    'Floating Orbs',      // animated
    'Sound Waves',        // animated
    'Geometric Grid',     // animated
    'Aurora Glow',        // animated
    'Honeycomb',          // static
    'Diagonal Stripes',   // static
    'Circuit Board',      // static
    'Starburst',          // static
  ];

  bool get _isStatic => patternIndex >= 5;

  @override
  Widget build(BuildContext context) {
    if (patternIndex <= 0) return const SizedBox.expand();

    // Static patterns don't need AnimatedBuilder
    if (_isStatic) {
      return CustomPaint(
        size: Size.infinite,
        painter: _getPainter(0),
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _getPainter(animation.value),
        );
      },
    );
  }

  CustomPainter _getPainter(double t) {
    switch (patternIndex) {
      case 1:  return _FloatingOrbsPainter(t, accentColor);
      case 2:  return _SoundWavesPainter(t, accentColor);
      case 3:  return _GeometricGridPainter(t, accentColor);
      case 4:  return _AuroraGlowPainter(t, accentColor);
      case 5:  return _HoneycombPainter(accentColor);
      case 6:  return _DiagonalStripesPainter(accentColor);
      case 7:  return _CircuitBoardPainter(accentColor);
      case 8:  return _StarburstPainter(accentColor);
      default: return _FloatingOrbsPainter(t, accentColor);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED PATTERNS
// ─────────────────────────────────────────────────────────────────────────────

// Pattern 1: Floating Orbs
class _FloatingOrbsPainter extends CustomPainter {
  final double t;
  final Color accent;
  _FloatingOrbsPainter(this.t, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    for (int i = 0; i < 10; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final radius = 50.0 + rng.nextDouble() * 80;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final phase = rng.nextDouble() * math.pi * 2;
      final alphaBase = 0.25 + rng.nextDouble() * 0.2;

      final dx = math.sin(t * math.pi * 2 * speed + phase) * 35;
      final dy = math.cos(t * math.pi * 2 * speed * 0.7 + phase) * 30;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: alphaBase),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(baseX + dx, baseY + dy),
          radius: radius,
        ));

      canvas.drawCircle(Offset(baseX + dx, baseY + dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingOrbsPainter old) => old.t != t;
}

// Pattern 2: Sound Waves
class _SoundWavesPainter extends CustomPainter {
  final double t;
  final Color accent;
  _SoundWavesPainter(this.t, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    for (int i = 0; i < 8; i++) {
      final progress = (t + i * 0.12) % 1.0;
      final radius = progress * size.height * 0.85;
      final alpha = (1.0 - progress) * 0.45;
      if (alpha <= 0) continue;

      final paint = Paint()
        ..color = accent.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + (1.0 - progress) * 3.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi * 0.85,
        math.pi * 0.7,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SoundWavesPainter old) => old.t != t;
}

// Pattern 3: Geometric Grid
class _GeometricGridPainter extends CustomPainter {
  final double t;
  final Color accent;
  _GeometricGridPainter(this.t, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 48.0;
    final cols = (size.width / spacing).ceil() + 2;
    final rows = (size.height / spacing).ceil() + 2;
    final offsetX = (t * spacing) % spacing;
    final offsetY = (t * spacing * 0.5) % spacing;

    for (int r = -1; r < rows; r++) {
      for (int c = -1; c < cols; c++) {
        final x = c * spacing + offsetX;
        final y = r * spacing + offsetY;

        final dx = x - size.width / 2;
        final dy = y - size.height / 2;
        final dist = math.sqrt(dx * dx + dy * dy);
        final maxDist = math.sqrt(size.width * size.width + size.height * size.height) / 2;
        final alpha = (1.0 - (dist / maxDist).clamp(0.0, 1.0)) * 0.45;
        if (alpha < 0.02) continue;

        final pulse = math.sin(t * math.pi * 2 + c * 0.5 + r * 0.3).abs();
        final dotRadius = 2.5 + pulse * 4.0;
        final paint = Paint()..color = accent.withValues(alpha: alpha);

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(t * math.pi * 0.5);
        final path = Path()
          ..moveTo(0, -dotRadius)
          ..lineTo(dotRadius, 0)
          ..lineTo(0, dotRadius)
          ..lineTo(-dotRadius, 0)
          ..close();
        canvas.drawPath(path, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GeometricGridPainter old) => old.t != t;
}

// Pattern 4: Aurora Glow
class _AuroraGlowPainter extends CustomPainter {
  final double t;
  final Color accent;
  _AuroraGlowPainter(this.t, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final hslBase = HSLColor.fromColor(accent);

    for (int band = 0; band < 5; band++) {
      final hue = (hslBase.hue + band * 30) % 360;
      final color = HSLColor.fromAHSL(1.0, hue, 0.85, 0.55).toColor();

      final path = Path();
      final yBase = size.height * (0.15 + band * 0.17);
      path.moveTo(-20, yBase);

      for (double x = -20; x <= size.width + 20; x += 8) {
        final wave1 = math.sin((x / size.width) * math.pi * 2 + t * math.pi * 2 + band) * 45;
        final wave2 = math.cos((x / size.width) * math.pi * 3 + t * math.pi * 1.5 + band * 0.5) * 25;
        path.lineTo(x, yBase + wave1 + wave2);
      }

      path.lineTo(size.width + 20, size.height + 20);
      path.lineTo(-20, size.height + 20);
      path.close();

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.06),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, yBase - 60, size.width, size.height * 0.5));

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraGlowPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// STATIC PATTERNS
// ─────────────────────────────────────────────────────────────────────────────

// Pattern 5: Honeycomb
class _HoneycombPainter extends CustomPainter {
  final Color accent;
  _HoneycombPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    const r = 28.0; // hex radius
    const w = r * 2;
    final h = math.sqrt(3) * r;
    final cols = (size.width / (w * 0.75)).ceil() + 2;
    final rows = (size.height / h).ceil() + 2;

    final strokePaint = Paint()
      ..color = accent.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = accent.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final cx = col * w * 0.75 + r;
        final cy = row * h + (col.isOdd ? h / 2 : 0) + r;

        final path = Path();
        for (int side = 0; side < 6; side++) {
          final angle = math.pi / 180 * (60 * side - 30);
          final px = cx + r * math.cos(angle);
          final py = cy + r * math.sin(angle);
          if (side == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();

        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HoneycombPainter old) => false;
}

// Pattern 6: Diagonal Stripes
class _DiagonalStripesPainter extends CustomPainter {
  final Color accent;
  _DiagonalStripesPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    const stripeWidth = 32.0;
    const gap = 20.0;
    const step = stripeWidth + gap;

    final paint = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;

    final diagonal = size.width + size.height;
    final count = (diagonal / step).ceil() + 2;

    for (int i = -2; i < count; i++) {
      final offset = i * step - size.height;
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        paint,
      );
    }

    // Soft vignette to fade edges
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.75,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignette);
  }

  @override
  bool shouldRepaint(covariant _DiagonalStripesPainter old) => false;
}

// Pattern 7: Circuit Board
class _CircuitBoardPainter extends CustomPainter {
  final Color accent;
  _CircuitBoardPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(99);
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.28)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final nodePaint = Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    const gridSize = 52.0;
    final cols = (size.width / gridSize).ceil() + 1;
    final rows = (size.height / gridSize).ceil() + 1;

    // Draw horizontal/vertical lines randomly
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final x = c * gridSize;
        final y = r * gridSize;

        if (rng.nextBool()) {
          canvas.drawLine(Offset(x, y), Offset(x + gridSize, y), linePaint);
        }
        if (rng.nextBool()) {
          canvas.drawLine(Offset(x, y), Offset(x, y + gridSize), linePaint);
        }
        // Draw node at intersections
        if (rng.nextDouble() > 0.6) {
          canvas.drawCircle(Offset(x, y), 3.5, nodePaint);
          // Outer ring
          final ringPaint = Paint()
            ..color = accent.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawCircle(Offset(x, y), 7.0, ringPaint);
        }
      }
    }

    // Vignette
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignette);
  }

  @override
  bool shouldRepaint(covariant _CircuitBoardPainter old) => false;
}

// Pattern 8: Starburst
class _StarburstPainter extends CustomPainter {
  final Color accent;
  _StarburstPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final maxR = math.sqrt(cx * cx + size.height * size.height);

    const rayCount = 24;
    for (int i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * math.pi * 2;
      final endX = cx + maxR * math.cos(angle);
      final endY = cy + maxR * math.sin(angle);

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            accent.withValues(alpha: 0.35),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromPoints(Offset(cx, cy), Offset(endX, endY)))
        ..strokeWidth = i.isEven ? 18.0 : 9.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;

      canvas.drawLine(Offset(cx, cy), Offset(endX, endY), paint);
    }

    // Bright center glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.50),
          accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 90));
    canvas.drawCircle(Offset(cx, cy), 90, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _StarburstPainter old) => false;
}
