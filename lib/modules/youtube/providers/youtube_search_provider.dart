import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// YouTube arama durumunu yöneten sınıf
class YoutubeState {
  final List<Video> searchResults;
  final bool isLoading;
  final bool isDownloading;
  final double downloadProgress;
  final String? error;

  YoutubeState({
    this.searchResults = const [],
    this.isLoading = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.error,
  });

  YoutubeState copyWith({
    List<Video>? searchResults,
    bool? isLoading,
    bool? isDownloading,
    double? downloadProgress,
    String? error,
  }) {
    return YoutubeState(
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      error: error,
    );
  }

  // Geçerli arama durumunun boş olup olmadığını kontrol et
  bool get hasNoResults => !isLoading && searchResults.isEmpty;
}

class YoutubeSearchNotifier extends StateNotifier<YoutubeState> {
  YoutubeSearchNotifier() : super(YoutubeState());

  final YoutubeExplode _yt = YoutubeExplode();

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }

  // Video araması yap
  Future<void> searchVideos(String query) async {
    if (query.isEmpty) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      searchResults: [],
    );

    try {
      final searchResults = await _yt.search.search(
        query,
        filter: DurationFilters.short,
      );

      final videos = await Future.wait(
        searchResults.take(20).map((video) async {
          try {
            return await _yt.videos.get(video.id);
          } catch (e) {
            print('Video detayı alınamadı: ${video.id} - $e');
            return video;
          }
        }),
      );

      state = state.copyWith(
        searchResults: videos,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Arama yapılırken bir hata oluştu: $e',
      );
    }
  }

  // İndirme işlemi durumunu güncelle
  void setDownloading(bool isDownloading) {
    state = state.copyWith(
      isDownloading: isDownloading,
      downloadProgress: isDownloading ? 0.0 : state.downloadProgress,
    );
  }

  // İndirme yüzdesini güncelle
  void updateDownloadProgress(double progress) {
    if (state.isDownloading) {
      state = state.copyWith(downloadProgress: progress);
    }
  }

  // Hata durumunu güncelle
  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  // Aramayı temizle
  void clearSearch() {
    state = YoutubeState();
  }

  // Video detaylarını getir
  Future<Video?> getVideoDetails(String videoId) async {
    try {
      return await _yt.videos.get(videoId);
    } catch (e) {
      state = state.copyWith(
        error: 'Video detayları alınamadı: $e',
      );
      return null;
    }
  }
}

// Provider tanımlaması
final youtubeSearchProvider =
    StateNotifierProvider<YoutubeSearchNotifier, YoutubeState>((ref) {
  return YoutubeSearchNotifier();
});
