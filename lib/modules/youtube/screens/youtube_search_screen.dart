import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../providers/youtube_search_provider.dart';
import '../widgets/youtube_search_bar.dart';
import '../widgets/video_list_item.dart';
import '../../../modules/audio/screens/clip_editor_screen.dart';

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

    try {
      ref.read(youtubeSearchProvider.notifier).setDownloading(true);

      var manifest = await _yt.videos.streamsClient.getManifest(video.id.value);
      var streamInfo = manifest.audioOnly.withHighestBitrate();

      if (streamInfo.size.totalBytes > 50 * 1024 * 1024) {
        throw Exception('Dosya boyutu çok büyük (50MB limit)');
      }

      // Temp dosya adını oluştur
      String safeFileName = video.title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final tempDir = await Directory.systemTemp.create();
      final tempFile = File('${tempDir.path}/$safeFileName.mp3');

      // Videoyu indir
      var stream = await _yt.videos.streamsClient.get(streamInfo);
      var fileStream = tempFile.openWrite();
      int receivedBytes = 0;

      await for (final data in stream) {
        fileStream.add(data);
        receivedBytes += data.length;
        double progress = (receivedBytes / streamInfo.size.totalBytes) * 100;
        ref
            .read(youtubeSearchProvider.notifier)
            .updateDownloadProgress(progress);
      }

      await fileStream.close();

      if (!mounted) return;

      // Clip editor'ı aç
      final editedPath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ClipEditorScreen(
            audioPath: tempFile.path,
            // folderId seçili klasörden gelecek
          ),
        ),
      );

      // Temp dosyayı temizle
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // Başarılı ise ana ekrana dön
      if (editedPath != null && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İndirme hatası: $e')),
        );
      }
    } finally {
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
