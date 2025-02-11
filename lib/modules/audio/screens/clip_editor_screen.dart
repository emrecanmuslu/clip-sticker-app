import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/clip_editor_provider.dart';
import '../providers/audio_provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
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
  bool _isPlaying = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _playerController.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    _playerController = PlayerController();

    try {
      await _playerController.preparePlayer(
        path: widget.audioPath,
        shouldExtractWaveform: true,
      );

      // Ses dosyasının süresini al
      final durationMs = await _playerController.getDuration() ?? 0;
      final durationSeconds = durationMs / 1000; // milisaniyeden saniyeye çevir

      String originalFileName = widget.audioPath.split('/').last;
      originalFileName = originalFileName.replaceAll(RegExp(r'\.mp3$'), '');

      if (!_nameController.text.startsWith('Klip_')) {
        _nameController.text = 'Klip_$originalFileName';
      }

      await ref.read(clipEditorProvider.notifier).loadAudio(widget.audioPath);
      setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ses dosyası yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      final editorState = ref.read(clipEditorProvider);

      if (_isPlaying) {
        await _playerController.pausePlayer();
      } else {
        // milliseconds cinsinden seekTo pozisyonunu hesapla
        final seekPosition = (editorState.startTime * 1000).toInt();
        await _playerController.seekTo(seekPosition);
        await _playerController.startPlayer();

        _playerController.onCurrentDurationChanged.listen((positionMs) {
          final currentPosition = positionMs / 1000; // saniyeye çevir
          if (currentPosition >= editorState.endTime) {
            _playerController.pausePlayer();
            _playerController.seekTo((editorState.startTime * 1000).toInt());
            setState(() => _isPlaying = false);
          }
        });
      }
      setState(() => _isPlaying = !_isPlaying);
    } catch (e) {
      print('Oynatma hatası: $e');
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

    final outputPath = await ref
        .read(clipEditorProvider.notifier)
        .saveClip(widget.audioPath, clipName);

    if (outputPath != null && mounted) {
      final audioNotifier = ref.read(audioProvider.notifier);
      await audioNotifier.addClip(File(outputPath),
          folderId: widget.folderId,
          customName: clipName,
          duration: clipDuration,
          keepFolderId: true);

      Navigator.of(context).pop();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Klip Oluştur'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: editorState.isLoading || !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                      _nameController.selection = TextSelection.fromPosition(
                        TextPosition(offset: sanitizedName.length),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Seçilen: ${_formatDuration(editorState.selectedDuration)} / '
                    'Maksimum: ${_formatDuration(ClipEditorState.maxDuration)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  CustomWaveform(
                    audioPath: widget.audioPath,
                    startTime: editorState.startTime,
                    endTime: editorState.endTime,
                    duration: editorState.duration,
                    playerController: _playerController,
                    maxDuration: ClipEditorState.maxDuration,
                    onSeek: (start, end) {
                      ref
                          .read(clipEditorProvider.notifier)
                          .updateTimeRange(start, end);
                    },
                    waveColor: Colors.grey.shade300,
                    selectedColor:
                        Theme.of(context).primaryColor.withOpacity(0.5),
                    backgroundColor: Colors.white,
                    height: 120,
                  ),
                  const SizedBox(height: 24),
                  IconButton(
                    iconSize: 64,
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle : Icons.play_circle,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: _togglePlayPause,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 48,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'KAYDET',
                              style: TextStyle(
                                fontSize: 16,
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
    );
  }
}
