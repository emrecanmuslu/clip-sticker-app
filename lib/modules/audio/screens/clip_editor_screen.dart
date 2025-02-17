import 'dart:io';
import 'dart:async';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../providers/clip_editor_provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/audio_waveform.dart';

class ClipEditorScreen extends ConsumerStatefulWidget {
  final String audioPath;
  final String? folderId;

  const ClipEditorScreen({
    super.key,
    required this.audioPath,
    this.folderId,
  });

  @override
  ConsumerState<ClipEditorScreen> createState() => _ClipEditorScreenState();
}

class _ClipEditorScreenState extends ConsumerState<ClipEditorScreen> {
  final TextEditingController _nameController = TextEditingController();
  late PlayerController _playerController;
  bool _isInitialized = false;
  StreamSubscription? _playerSubscription;
  String? _preparedAudioPath;

  @override
  void initState() {
    super.initState();
    _initializeEditor();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _playerSubscription?.cancel();
    _playerController.dispose();
    _cleanupTempFiles();
    super.dispose();
  }

  Future<void> _cleanupTempFiles() async {
    if (_preparedAudioPath != null) {
      try {
        final file = File(_preparedAudioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Geçici dosya temizleme hatası: $e');
      }
    }
  }

  Future<void> _initializeEditor() async {
    try {
      _playerController = PlayerController();

      // iOS için ses dosyasını geçici dizine kopyala
      String audioFilePath = widget.audioPath;
      if (Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final fileName = path.basename(widget.audioPath);
        _preparedAudioPath = path.join(tempDir.path, 'prepared_$fileName');

        // Orijinal dosyayı geçici konuma kopyala
        await File(widget.audioPath).copy(_preparedAudioPath!);
        audioFilePath = _preparedAudioPath!;
      }

      // Waveform için ses dosyasını hazırla
      await _playerController.preparePlayer(
        path: audioFilePath,
        shouldExtractWaveform: true,
        noOfSamples: 300,
      );

      // Dosya adını ayarla
      String originalFileName = path.basenameWithoutExtension(widget.audioPath);
      _nameController.text = originalFileName;

      // Provider'ı başlat
      await ref.read(clipEditorProvider.notifier).loadAudio(audioFilePath);

      // Oynatma pozisyonunu takip et
      _playerSubscription =
          _playerController.onCurrentDurationChanged.listen((positionMs) {
        final currentPosition = positionMs / 1000;
        final editorState = ref.read(clipEditorProvider);

        if (currentPosition >= editorState.endTime) {
          _playerController.seekTo((editorState.startTime * 1000).toInt());
          _playerController.pausePlayer();
        }
      });

      setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ses dosyası yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _saveClip() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir isim girin')),
      );
      return;
    }

    String clipName = _nameController.text;
    final editorState = ref.read(clipEditorProvider);
    final clipDuration = editorState.endTime - editorState.startTime;

    // iOS için geçici dosya yolunu kullan
    final sourcePath = Platform.isIOS ? _preparedAudioPath! : widget.audioPath;

    final outputPath = await ref
        .read(clipEditorProvider.notifier)
        .saveClip(sourcePath, clipName);

    if (outputPath != null && mounted) {
      final audioNotifier = ref.read(audioProvider.notifier);
      await audioNotifier.addClip(
        File(outputPath),
        folderId: widget.folderId,
        customName: clipName,
        duration: clipDuration,
        keepFolderId: true,
      );

      Navigator.of(context).pop(outputPath);
    }
  }

  String _formatDuration(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).toInt());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(clipEditorProvider);

    return WillPopScope(
      onWillPop: () async {
        await _playerController.pausePlayer();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Klip Oluştur'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: editorState.isLoading || !_isInitialized
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Klip İsmi
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Klip İsmi',
                          border: OutlineInputBorder(),
                          hintText: 'Klip için özel bir isim girin',
                        ),
                        onChanged: (value) {
                          final sanitizedName = value.trim();
                          _nameController.text = sanitizedName;
                          _nameController.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: sanitizedName.length),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // 2. Süre Bilgisi
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Seçilen: ${_formatDuration(editorState.selectedDuration)} / '
                          'Maksimum: ${_formatDuration(ClipEditorState.maxDuration)}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 3. Ses Dalgası
                      Container(
                        height: 280,
                        child: CustomWaveform(
                          audioPath: widget.audioPath,
                          startTime: editorState.startTime,
                          endTime: editorState.endTime,
                          duration: editorState.duration,
                          maxDuration: ClipEditorState.maxDuration,
                          playerController: _playerController,
                          onSeek: (start, end) {
                            ref
                                .read(clipEditorProvider.notifier)
                                .updateTimeRange(start, end);
                          },
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 4. Kaydet Butonu
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: editorState.isSaving ? null : _saveClip,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: editorState.isSaving
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'KAYDET',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      if (editorState.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            editorState.error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
