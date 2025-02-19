import 'dart:io';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../providers/youtube_search_provider.dart';
import '../widgets/youtube_search_bar.dart';
import '../widgets/video_list_item.dart';
import '../../../modules/audio/screens/clip_editor_screen.dart';
import 'package:path/path.dart' as path;

class YoutubeSearchScreen extends ConsumerStatefulWidget {
  const YoutubeSearchScreen({super.key});

  @override
  ConsumerState<YoutubeSearchScreen> createState() =>
      _YoutubeSearchScreenState();
}

class _YoutubeSearchScreenState extends ConsumerState<YoutubeSearchScreen> {
  final YoutubeExplode _yt = YoutubeExplode();

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }

  Future<bool> _checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İnternet bağlantısı bulunamadı')),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _downloadAndOpenEditor(Video video) async {
    if (!await _checkInternetConnection()) return;

    String? tempFilePath;
    String? tempOutputPath;

    try {
      ref.read(youtubeSearchProvider.notifier).setDownloading(true);

      var manifest = await _yt.videos.streamsClient.getManifest(video.id.value);
      var streamInfo = manifest.audioOnly
          .where((s) => s.size.totalBytes <= 50 * 1024 * 1024) // 50MB limit
          .toList()
          .last;

      if (streamInfo == null) {
        throw Exception('Uygun ses kalitesi bulunamadı');
      }

      // Geçici dosya oluştur
      final tempDir = await getTemporaryDirectory();
      final safeFileName = video.title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();

      tempFilePath = path.join(tempDir.path, '${safeFileName}_temp.m4a');
      tempOutputPath = path.join(tempDir.path, '${safeFileName}.mp3');

      // Sesi indir
      var stream = await _yt.videos.streamsClient.get(streamInfo);
      var fileStream = File(tempFilePath).openWrite();
      int receivedBytes = 0;
      int totalBytes = streamInfo.size.totalBytes;

      await for (final data in stream) {
        fileStream.add(data);
        receivedBytes += data.length;
        double progress = (receivedBytes / totalBytes) * 100;
        ref
            .read(youtubeSearchProvider.notifier)
            .updateDownloadProgress(progress);
      }

      await fileStream.close();

      // iOS için ses dönüşümü
      if (Platform.isIOS) {
        // Önce opus'u AAC'ye dönüştür
        final intermediateFile =
            path.join(tempDir.path, '${safeFileName}_intermediate.m4a');

        final command =
            '-i "$tempFilePath" -c:a aac -b:a 192k -ar 44100 "$intermediateFile"';

        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();
        final logs = await session.getLogs();

        print('FFmpeg komut çıktısı: ${logs.join("\n")}');

        if (!ReturnCode.isSuccess(returnCode)) {
          throw Exception('Ses dönüştürme başarısız oldu: ${logs.join("\n")}');
        }

        // Geçici dosyaları temizle
        await File(tempFilePath).delete();
        tempFilePath = intermediateFile;
      }

      if (!mounted) return;

      // Clip editor'ı aç
      final editedPath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ClipEditorScreen(
            audioPath: tempFilePath!,
          ),
        ),
      );

      // Başarılı ise ana ekrana dön
      if (editedPath != null && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('Hata detayı: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İndirme hatası: $e')),
        );
      }
    } finally {
      // Temizlik
      for (var path in [tempFilePath, tempOutputPath]) {
        if (path != null) {
          try {
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
        }
      }

      ref.read(youtubeSearchProvider.notifier).setDownloading(false);
      ref.read(youtubeSearchProvider.notifier).updateDownloadProgress(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final youtubeState = ref.watch(youtubeSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube\'dan İndir'),
      ),
      body: Stack(
        // Column yerine Stack kullanıyoruz
        children: [
          Column(
            children: [
              const YoutubeSearchBar(),
              Expanded(
                child: youtubeState.searchResults.isEmpty &&
                        !youtubeState.isLoading
                    ? const Center(
                        child: Text('Aramak istediğiniz videoyu yazın'),
                      )
                    : youtubeState.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: youtubeState.searchResults.length,
                            itemBuilder: (context, index) {
                              final video = youtubeState.searchResults[index];
                              return VideoListItem(
                                video: video,
                                isDownloading: youtubeState.isDownloading,
                                onDownload: _downloadAndOpenEditor,
                              );
                            },
                          ),
              ),
            ],
          ),
          // İndirme Göstergesi en üstte
          if (youtubeState.isDownloading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'İndiriliyor... %${youtubeState.downloadProgress.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
