import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl/services/audio_service.dart';

void main() {
  group('interruptionActionFor', () {
    test('another app starts playing: pause', () {
      expect(
        interruptionActionFor(AudioInterruptionEvent(true, AudioInterruptionType.pause)),
        InterruptionAction.pause,
      );
      expect(
        interruptionActionFor(AudioInterruptionEvent(true, AudioInterruptionType.unknown)),
        InterruptionAction.pause,
      );
    });

    test('another app stops playing: do NOT resume the music', () {
      expect(
        interruptionActionFor(AudioInterruptionEvent(false, AudioInterruptionType.pause)),
        InterruptionAction.none,
      );
      expect(
        interruptionActionFor(AudioInterruptionEvent(false, AudioInterruptionType.unknown)),
        InterruptionAction.none,
      );
    });

    test('short sounds (navigation prompt, notification): duck, then restore volume', () {
      expect(
        interruptionActionFor(AudioInterruptionEvent(true, AudioInterruptionType.duck)),
        InterruptionAction.duck,
      );
      expect(
        interruptionActionFor(AudioInterruptionEvent(false, AudioInterruptionType.duck)),
        InterruptionAction.unduck,
      );
    });
  });
}
