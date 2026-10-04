import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Material 3 Expressive style progress track for a [Slider].
///
/// The played part is a wavy line that travels along the track while music
/// plays; the remaining part is a flat rounded line, separated from the played
/// part by a small gap around the handle, and ends in a small dot. When music
/// is paused the wave eases out to a straight line.
class WavySliderTrackShape extends SliderTrackShape {
  /// Phase of the travelling wave, 0..1 (one full wavelength per cycle).
  final double waveAnimationValue;

  /// True while music is playing and the wave is enabled.
  final bool isPlaying;

  /// Current wave height, 0 (straight) .. 1 (full). Animate this to ease
  /// the wave in and out.
  final double amplitude;

  const WavySliderTrackShape({
    required this.waveAnimationValue,
    required this.isPlaying,
    this.amplitude = 1.0,
  });

  static const double _strokeWidth = 4.5;
  static const double _inactiveStrokeWidth = 4.0;
  static const double _waveHeight = 3.2;
  static const double _wavelength = 36.0;
  static const double _gap = 7.0;
  static const double _stopDotRadius = 2.0;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    const trackHeight = 14.0; // room for the wave
    final top = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(offset.dx, top, parentBox.size.width, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final canvas = context.canvas;
    final activeColor = sliderTheme.activeTrackColor ?? Colors.purpleAccent;
    final inactiveColor = sliderTheme.inactiveTrackColor ?? Colors.white24;

    final cy = rect.center.dy;
    final left = rect.left + _strokeWidth / 2;
    final right = rect.right - _strokeWidth / 2;
    final activeEnd = thumbCenter.dx - _gap;
    final inactiveStart = thumbCenter.dx + _gap;

    // Remaining (flat) part, with a stop dot at its end.
    if (inactiveStart < right) {
      canvas.drawLine(
        Offset(inactiveStart, cy),
        Offset(right, cy),
        Paint()
          ..color = inactiveColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _inactiveStrokeWidth
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(right - _stopDotRadius, cy),
        _stopDotRadius,
        Paint()..color = activeColor,
      );
    }

    // Played part: wavy while playing, a straight line otherwise.
    if (activeEnd > left) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final height = _waveHeight * amplitude.clamp(0.0, 1.0);
      if (height < 0.05) {
        canvas.drawLine(Offset(left, cy), Offset(activeEnd, cy), activePaint);
      } else {
        final k = 2 * math.pi / _wavelength;
        final phase = waveAnimationValue * 2 * math.pi;
        final path = Path()..moveTo(left, cy + math.sin(-phase) * height);
        for (double x = left + 1.5; x < activeEnd; x += 1.5) {
          path.lineTo(x, cy + math.sin((x - left) * k - phase) * height);
        }
        path.lineTo(activeEnd, cy + math.sin((activeEnd - left) * k - phase) * height);
        canvas.drawPath(path, activePaint);
      }
    }
  }
}

/// Material 3 Expressive slider handle: a slim vertical rounded bar that
/// narrows slightly while it is being dragged.
class WavyHandleSliderThumbShape extends SliderComponentShape {
  final double height;
  final double width;

  const WavyHandleSliderThumbShape({this.height = 28, this.width = 5});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final w = width - 2 * activationAnimation.value; // narrows while pressed
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: w, height: height),
      Radius.circular(w / 2),
    );
    context.canvas.drawRRect(
      rrect,
      Paint()..color = sliderTheme.thumbColor ?? Colors.purpleAccent,
    );
  }
}
