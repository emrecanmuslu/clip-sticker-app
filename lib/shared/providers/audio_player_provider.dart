import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerNotifier extends StateNotifier<AudioPlayer> {
  String? _currentPath;
  bool _isPlaying = false;

  String? get currentPath => _currentPath;

  bool get isPlaying => _isPlaying;

  final _playingStateController = StreamController<bool>.broadcast();

  Stream<bool> get playingStream => _playingStateController.stream;

  AudioPlayerNotifier() : super(AudioPlayer()) {
    state.playerStateStream.listen((playerState) {
      _isPlaying = playerState.playing;
      _playingStateController.add(_isPlaying);

      if (playerState.processingState == ProcessingState.completed) {
        state.seek(Duration.zero);
        state.pause();
      }
    });
  }

  Future<void> loadFile(String filePath) async {
    try {
      await state.setFilePath(filePath);
    } catch (e) {
      print('Ses yükleme hatası: $e');
      rethrow;
    }
  }

  Future<void> playClip(String path) async {
    try {
      if (_currentPath == path && _isPlaying) {
        await pause();
        return;
      }

      _isPlaying = true;
      _playingStateController.add(_isPlaying);

      if (_currentPath != path) {
        _currentPath = path;
        await state.setFilePath(path);
      }

      await state.play();
    } catch (e) {
      _isPlaying = false;
      _playingStateController.add(_isPlaying);
      print('Oynatma hatası: $e');
      rethrow;
    }
  }

  Future<void> play({Duration? from, Duration? to}) async {
    try {
      if (from != null || to != null) {
        await state.setClip(start: from, end: to);
      }
      _isPlaying = true;
      _playingStateController.add(_isPlaying);
      await state.play();
    } catch (e) {
      _isPlaying = false;
      _playingStateController.add(_isPlaying);
      print('Oynatma hatası: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      _isPlaying = false;
      _playingStateController.add(_isPlaying);
      await state.pause();
    } catch (e) {
      print('Durdurma hatası: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      _isPlaying = false;
      _playingStateController.add(_isPlaying);
      await state.stop();
    } catch (e) {
      print('Durdurma hatası: $e');
      rethrow;
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await state.seek(position);
    } catch (e) {
      print('Konum değiştirme hatası: $e');
      rethrow;
    }
  }

  Future<Duration?> getDuration() async {
    return state.duration;
  }

  Stream<Duration?> get positionStream => state.positionStream;

  Stream<Duration?> get durationStream => state.durationStream;

  Stream<PlayerState> get playerStateStream => state.playerStateStream;

  @override
  void dispose() {
    _playingStateController.close();
    state.dispose();
    super.dispose();
  }
}

final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayer>((ref) {
  return AudioPlayerNotifier();
});
