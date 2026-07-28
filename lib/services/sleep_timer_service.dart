import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pixel_player/services/audio_service.dart';

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
      notifyListeners();
      // End of song is handled by checking playback state completion listener
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
    _remainingTime = Duration.zero;
    _mode = SleepTimerMode.off;
    notifyListeners();
  }
}
