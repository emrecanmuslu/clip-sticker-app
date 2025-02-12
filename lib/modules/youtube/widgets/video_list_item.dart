import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../screens/youtube_preview_screen.dart';

class VideoListItem extends StatelessWidget {
  final Video video;
  final bool isDownloading;
  final Function(Video) onDownload;

  const VideoListItem({
    super.key,
    required this.video,
    required this.isDownloading,
    required this.onDownload,
  });

  bool get _isSelectable {
    final duration = video.duration;
    return duration != null && duration.inMinutes <= 4;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          // Thumbnail ve İndirme Butonu
          Stack(
            children: [
              // Thumbnail
              GestureDetector(
                onTap: () async {
                  if (!_isSelectable) return;

                  final result = await Navigator.push<Video>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => YoutubePreviewScreen(video: video),
                    ),
                  );

                  if (result != null) {
                    onDownload(result);
                  }
                },
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    video.thumbnails.mediumResUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
              ),
              // Süre Göstergesi
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    video.duration?.toString().split('.').first ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              // 4 Dakika Uyarısı
              if (!_isSelectable)
                Positioned.fill(
                  child: Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Text(
                        '4 dakikadan uzun',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Video Bilgileri
          InkWell(
            onTap: isDownloading || !_isSelectable
                ? null
                : () => onDownload(video),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _isSelectable ? null : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    video.author,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isSelectable ? Colors.grey[600] : Colors.grey,
                    ),
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
