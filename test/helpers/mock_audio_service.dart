import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pixel_player/data/models/song_model.dart';
import 'package:pixel_player/services/audio_service.dart';

/// Mock AudioPlayerService for headless unit & integration tests
class MockAudioPlayerService implements AudioPlayerService {
  final _playerStateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _currentIndexController = StreamController<int?>.broadcast();

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = 0;

  @override
  AudioPlayer get player => AudioPlayer();

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => Stream.value(const Duration(minutes: 3));

  @override
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  @override
  Future<void> play(String path, {Song? songInfo}) async {
    _currentSong = songInfo;
    _playerStateController.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> playQueue(List<Song> queue, {required int initialIndex}) async {
    _queue = List.from(queue);
    _currentIndex = initialIndex;
    _currentIndexController.add(_currentIndex);
    if (queue.isNotEmpty) {
      _currentSong = queue[initialIndex];
    }
    _playerStateController.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> pause() async {
    _playerStateController.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> resume() async {
    _playerStateController.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> stop() async {
    _playerStateController.add(PlayerState(false, ProcessingState.idle));
  }

  @override
  Future<void> seek(Duration position) async {
    _positionController.add(position);
  }

  @override
  Future<void> prepare(Song song) async {
    _currentSong = song;
  }

  @override
  Future<void> seekToNext() async {
    if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
      _currentIndex++;
      _currentIndexController.add(_currentIndex);
      _currentSong = _queue[_currentIndex];
    }
  }

  @override
  Future<void> seekToPrevious() async {
    if (_queue.isNotEmpty && _currentIndex > 0) {
      _currentIndex--;
      _currentIndexController.add(_currentIndex);
      _currentSong = _queue[_currentIndex];
    }
  }

  @override
  Future<void> seekToIndex(int index) async {
    _currentIndex = index;
    _currentIndexController.add(_currentIndex);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  void dispose() {
    _playerStateController.close();
    _positionController.close();
    _currentIndexController.close();
  }
}

/// Setup channel mocks for platform plugins in headless test environment
void setupPlatformMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.ryanheise.just_audio.methods');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    if (methodCall.method == 'init') {
      return {'id': 'test_player_id'};
    }
    if (methodCall.method == 'dispose') {
      return {};
    }
    if (methodCall.method == 'load') {
      return {'duration': 180000000};
    }
    return {};
  });
}
