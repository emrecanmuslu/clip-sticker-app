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
      child: InkWell(
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
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Thumbnail kısmı
              Stack(
                children: [
                  // Lazy loading ile thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,
                      height: 68, // 16:9 oranı için
                      child: Image.network(
                        video.thumbnails.mediumResUrl,
                        fit: BoxFit.cover,
                        frameBuilder:
                            (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) return child;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: frame != null
                                ? child
                                : Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),
                  // Süre göstergesi
                  if (video.duration != null)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.duration.toString().split('.').first,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  // 4 dakika uyarısı
                  if (!_isSelectable)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Text(
                              '4dk+',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Video bilgileri
              Expanded(
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
                    const SizedBox(height: 4),
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
              // İndirme butonu
              if (_isSelectable && !isDownloading)
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  onPressed: () => onDownload(video),
                  tooltip: 'İndir',
                  color: Theme.of(context).primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
