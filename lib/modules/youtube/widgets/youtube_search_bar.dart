import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/youtube_search_provider.dart';

class YoutubeSearchBar extends ConsumerStatefulWidget {
  const YoutubeSearchBar({super.key});

  @override
  ConsumerState<YoutubeSearchBar> createState() => _YoutubeSearchBarState();
}

class _YoutubeSearchBarState extends ConsumerState<YoutubeSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSearch() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      ref.read(youtubeSearchProvider.notifier).searchVideos(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'YouTube\'da ara...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: const Icon(Icons.youtube_searched_for),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {}); // Sadece UI güncellemesi için
              },
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_controller.text.isNotEmpty) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _handleSearch,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                minimumSize: const Size(0, 55),
              ),
              child: const Text('Ara'),
            ),
          ],
        ],
      ),
    );
  }
}
