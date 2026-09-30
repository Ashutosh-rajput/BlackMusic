import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vinyl/services/audio_service.dart';

enum SleepTimerMode {
  off,
  minutes15,
  minutes30,
  minutes45,
  minutes60,
  endOfSong,
}

class SleepTimerService extends ChangeNotifier {
  static final SleepTimerService _instance = SleepTimerService._internal();
  factory SleepTimerService() => _instance;
  SleepTimerService._internal();

  Timer? _timer;
  StreamSubscription? _endOfSongSubscription;
  StreamSubscription? _completedSubscription;
  StreamSubscription? _positionSubscription;
  Duration _remainingTime = Duration.zero;
  SleepTimerMode _mode = SleepTimerMode.off;

  Duration get remainingTime => _remainingTime;
  SleepTimerMode get mode => _mode;
  bool get isActive => _mode != SleepTimerMode.off;

  void startTimer(SleepTimerMode mode, {required AudioPlayerService audioService}) {
    cancelTimer();
    _mode = mode;

    if (mode == SleepTimerMode.off) {
      notifyListeners();
      return;
    }

    if (mode == SleepTimerMode.endOfSong) {
      int? initialIndex = audioService.currentIndex;
      Duration lastPosition = audioService.position;

      void onSongEnded() {
        cancelTimer();
        audioService.pause();
      }

      _endOfSongSubscription = audioService.currentIndexStream.listen((index) {
        if (index == null) return;
        if (initialIndex == null) {
          initialIndex = index;
        } else if (index != initialIndex) {
          onSongEnded();
        }
      });

      _completedSubscription = audioService.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          onSongEnded();
        }
      });

      _positionSubscription = audioService.positionStream.listen((pos) {
        final dur = audioService.duration;
        if (dur != null && dur > Duration.zero) {
          // Detect loop repeat in LoopMode.one
          if (lastPosition > Duration.zero &&
              lastPosition >= dur - const Duration(seconds: 1) &&
              pos < const Duration(seconds: 1)) {
            onSongEnded();
          }
        }
        lastPosition = pos;
      });

      notifyListeners();
      return;
    }

    int minutes = 15;
    switch (mode) {
      case SleepTimerMode.minutes15:
        minutes = 15;
        break;
      case SleepTimerMode.minutes30:
        minutes = 30;
        break;
      case SleepTimerMode.minutes45:
        minutes = 45;
        break;
      case SleepTimerMode.minutes60:
        minutes = 60;
        break;
      default:
        break;
    }

    _remainingTime = Duration(minutes: minutes);
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingTime.inSeconds <= 1) {
        _remainingTime = Duration.zero;
        _mode = SleepTimerMode.off;
        t.cancel();
        audioService.pause();
        notifyListeners();
      } else {
        _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
        notifyListeners();
      }
    });
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _endOfSongSubscription?.cancel();
    _endOfSongSubscription = null;
    _completedSubscription?.cancel();
    _completedSubscription = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _remainingTime = Duration.zero;
    _mode = SleepTimerMode.off;
    notifyListeners();
  }
}
