import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vinyl/services/sleep_timer_service.dart';
import 'helpers/mock_audio_service.dart';

void main() {
  setupPlatformMocks();

  group('SleepTimerService Tests', () {
    late MockAudioPlayerService audioService;
    late SleepTimerService timerService;

    setUp(() {
      audioService = MockAudioPlayerService();
      timerService = SleepTimerService();
      timerService.cancelTimer();
    });

    tearDown(() {
      timerService.cancelTimer();
      audioService.dispose();
    });

    test('Initial state is inactive and off', () {
      expect(timerService.isActive, isFalse);
      expect(timerService.mode, equals(SleepTimerMode.off));
      expect(timerService.remainingTime, equals(Duration.zero));
    });

    test('startTimer with minutes sets remainingTime and active mode', () {
      timerService.startTimer(SleepTimerMode.minutes15, audioService: audioService);
      expect(timerService.isActive, isTrue);
      expect(timerService.mode, equals(SleepTimerMode.minutes15));
      expect(timerService.remainingTime.inMinutes, equals(15));
    });

    test('cancelTimer resets mode and remainingTime to zero', () {
      timerService.startTimer(SleepTimerMode.minutes30, audioService: audioService);
      expect(timerService.isActive, isTrue);

      timerService.cancelTimer();
      expect(timerService.isActive, isFalse);
      expect(timerService.mode, equals(SleepTimerMode.off));
      expect(timerService.remainingTime, equals(Duration.zero));
    });

    test('endOfSong mode pauses audio and turns off when track index changes', () async {
      audioService.emitCurrentIndex(0);
      timerService.startTimer(SleepTimerMode.endOfSong, audioService: audioService);
      expect(timerService.isActive, isTrue);
      expect(timerService.mode, equals(SleepTimerMode.endOfSong));

      // Simulate next track transition
      audioService.emitCurrentIndex(1);
      await pumpEventQueue();

      expect(timerService.isActive, isFalse);
      expect(timerService.mode, equals(SleepTimerMode.off));
      expect(audioService.isPlaying, isFalse);
    });

    test('endOfSong mode pauses audio and turns off when song completes', () async {
      timerService.startTimer(SleepTimerMode.endOfSong, audioService: audioService);
      expect(timerService.isActive, isTrue);

      // Simulate playback completion
      audioService.emitPlayerState(PlayerState(false, ProcessingState.completed));
      await pumpEventQueue();

      expect(timerService.isActive, isFalse);
      expect(timerService.mode, equals(SleepTimerMode.off));
      expect(audioService.isPlaying, isFalse);
    });
  });
}

