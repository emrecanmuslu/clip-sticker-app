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
    String? cachedFilePath;

    try {
      ref.read(youtubeSearchProvider.notifier).setDownloading(true);

      var manifest = await _yt.videos.streamsClient.getManifest(video.id.value);
      // En iyi ses kalitesini seç
      var streamInfo = manifest.audioOnly
          .where((s) => s.size.totalBytes <= 50 * 1024 * 1024) // 50MB limit
          .toList()
          .last;

      if (streamInfo == null) {
        throw Exception('Uygun ses kalitesi bulunamadı');
      }

      // Geçici dosya oluştur
      final tempDir = await getTemporaryDirectory();
      final safeFileName = _getSafeFileName(video.title);
      tempFilePath =
          path.join(tempDir.path, '$safeFileName.m4a'); // iOS uyumlu format

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

      if (!mounted) return;

      // iOS için ses dosyasını hazırla
      if (Platform.isIOS) {
        try {
          // FFmpeg ile ses dönüşümü yap
          final outputPath =
              path.join(tempDir.path, '${safeFileName}_converted.m4a');

          final session = await FFmpegKit.execute(
              '-i "$tempFilePath" -c:a aac -b:a 128k "$outputPath"');

          final returnCode = await session.getReturnCode();

          if (!ReturnCode.isSuccess(returnCode)) {
            throw Exception('Ses dönüştürme başarısız oldu');
          }

          // Cache manager ile hazırla
          final file = await DefaultCacheManager().putFile(
            'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
            File(outputPath).readAsBytesSync(),
            maxAge: const Duration(days: 1),
          );

          cachedFilePath = file.path;

          // Geçici dönüşüm dosyasını temizle
          if (await File(outputPath).exists()) {
            await File(outputPath).delete();
          }
        } catch (e) {
          print('Ses dönüştürme hatası: $e');
          // Dönüşüm başarısız olursa orijinal dosyayı kullan
          cachedFilePath = tempFilePath;
        }
      }

      if (!mounted) return;

      // Clip editor'ı aç
      final editedPath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ClipEditorScreen(
            audioPath: Platform.isIOS ? cachedFilePath! : tempFilePath!,
          ),
        ),
      );

      // Başarılı ise ana ekrana dön
      if (editedPath != null && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İndirme hatası: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Temizlik
      await _cleanupTempFiles([tempFilePath, cachedFilePath]);
      ref.read(youtubeSearchProvider.notifier).setDownloading(false);
      ref.read(youtubeSearchProvider.notifier).updateDownloadProgress(0);
    }
  }

  String _getSafeFileName(String title) {
    return title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  Future<void> _cleanupTempFiles(List<String?> paths) async {
    for (final path in paths) {
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('Dosya temizleme hatası: $e');
        }
      }
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
