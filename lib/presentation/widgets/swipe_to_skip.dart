import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vinyl/presentation/bloc/player/player_bloc.dart';
import 'package:vinyl/presentation/bloc/player/player_event.dart';

/// Lets the user swipe [child] sideways to change song: left plays the next
/// song, right plays the previous one. The child follows the finger and
/// springs back when released.
///
/// A quick flick or a drag of at least [swipeDistance] counts as a swipe;
/// anything smaller does nothing. Taps pass through to the child.
class SwipeToSkip extends StatefulWidget {
  final Widget child;

  /// How far the child may follow the finger.
  final double maxTravel;

  /// Drag distance (px) that counts as a swipe.
  final double swipeDistance;

  /// Flick speed (px/s) that counts as a swipe.
  final double swipeVelocity;

  const SwipeToSkip({
    super.key,
    required this.child,
    this.maxTravel = 140,
    this.swipeDistance = 60,
    this.swipeVelocity = 350,
  });

  @override
  State<SwipeToSkip> createState() => _SwipeToSkipState();
}

class _SwipeToSkipState extends State<SwipeToSkip> {
  final ValueNotifier<double> _dragX = ValueNotifier<double>(0);

  @override
  void dispose() {
    _dragX.dispose();
    super.dispose();
  }

  void _onDragEnd(DragEndDetails details) {
    final travelled = _dragX.value;
    final velocity = details.primaryVelocity ?? 0;
    _dragX.value = 0;

    final left = velocity < -widget.swipeVelocity || travelled < -widget.swipeDistance;
    final right = velocity > widget.swipeVelocity || travelled > widget.swipeDistance;
    final bloc = context.read<PlayerBloc>();
    if (left) {
      HapticFeedback.lightImpact();
      bloc.add(const NextSongEvent(isManualSkip: true));
    } else if (right) {
      HapticFeedback.lightImpact();
      bloc.add(const PreviousSongEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        _dragX.value = (_dragX.value + d.delta.dx).clamp(-widget.maxTravel, widget.maxTravel);
      },
      onHorizontalDragCancel: () => _dragX.value = 0,
      onHorizontalDragEnd: _onDragEnd,
      child: ValueListenableBuilder<double>(
        valueListenable: _dragX,
        child: widget.child,
        builder: (context, dx, child) => AnimatedContainer(
          // No animation while the finger is down; spring back on release.
          duration: dx == 0 ? const Duration(milliseconds: 220) : Duration.zero,
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(dx, 0, 0),
          child: child,
        ),
      ),
    );
  }
}
