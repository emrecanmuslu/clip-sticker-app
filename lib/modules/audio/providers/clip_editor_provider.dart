import 'dart:io';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ClipEditorState {
  final double startTime;
  final double endTime;
  final double duration;
  final bool isPlaying;
  final bool isSaving;
  final bool isLoading;
  final String? error;

  static const double maxDuration = 40.0;

  ClipEditorState({
    this.startTime = 0.0,
    this.endTime = 0.0,
    this.duration = 0.0,
    this.isPlaying = false,
    this.isSaving = false,
    this.isLoading = false,
    this.error,
  });

  ClipEditorState copyWith({
    double? startTime,
    double? endTime,
    double? duration,
    bool? isPlaying,
    bool? isSaving,
    bool? isLoading,
    String? error,
  }) {
    return ClipEditorState(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isValid => endTime - startTime <= maxDuration;

  double get selectedDuration => endTime - startTime;
}

class ClipEditorNotifier extends StateNotifier<ClipEditorState> {
  ClipEditorNotifier() : super(ClipEditorState());

  Future<void> loadAudio(String filePath) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Ses dosyası bulunamadı');
      }

      final probe = await FFprobeKit.execute(
          '-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$filePath"');

      final output = await probe.getOutput();
      if (output == null || output.isEmpty) {
        throw Exception('Ses süresi alınamadı');
      }

      final duration = double.parse(output.trim());

      state = state.copyWith(
        duration: duration,
        endTime: duration > ClipEditorState.maxDuration
            ? ClipEditorState.maxDuration
            : duration,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Ses dosyası yüklenemedi: $e',
      );
    }
  }

  void updateTimeRange(double start, double end) {
    if (start < 0 || end > state.duration || start >= end) return;

    if (end - start > ClipEditorState.maxDuration) {
      end = start + ClipEditorState.maxDuration;
    }

    state = state.copyWith(
      startTime: start,
      endTime: end,
    );
  }

  void setPlaying(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);
  }

  Future<String?> saveClip(String sourceFile, String clipName) async {
    if (!state.isValid) {
      state = state.copyWith(error: 'Geçersiz seçim süresi');
      return null;
    }

    state = state.copyWith(isSaving: true, error: null);
    String? outputPath;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory(path.join(appDir.path, 'audios'));

      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final safeFileName = clipName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      outputPath = path.join(audioDir.path, '${timestamp}_$safeFileName.mp3');

      final command =
          '-y -i "$sourceFile" -ss ${state.startTime} -t ${state.selectedDuration} -c:a libmp3lame -q:a 2 "$outputPath"';
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getLogs();
        throw Exception('Ses kesme işlemi başarısız oldu: ${logs.join("\n")}');
      }

      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        throw Exception('Çıktı dosyası oluşturulamadı');
      }

      state = state.copyWith(isSaving: false);
      return outputPath;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Kaydetme hatası: $e',
      );

      if (outputPath != null) {
        try {
          final file = File(outputPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
      return null;
    }
  }
}

final clipEditorProvider =
    StateNotifierProvider.autoDispose<ClipEditorNotifier, ClipEditorState>(
        (ref) {
  return ClipEditorNotifier();
});
