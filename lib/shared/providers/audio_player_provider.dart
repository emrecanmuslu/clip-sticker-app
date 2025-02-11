import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerNotifier extends StateNotifier<AudioPlayer> {
  AudioPlayerNotifier() : super(AudioPlayer()) {
    state.playerStateStream.listen((playerState) {
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

  Future<void> play({Duration? from, Duration? to}) async {
    try {
      if (from != null || to != null) {
        await state.setClip(start: from, end: to);
      }
      await state.play();
    } catch (e) {
      print('Oynatma hatası: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await state.pause();
    } catch (e) {
      print('Durdurma hatası: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
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
    state.dispose();
    super.dispose();
  }
}

final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayer>((ref) {
  return AudioPlayerNotifier();
});