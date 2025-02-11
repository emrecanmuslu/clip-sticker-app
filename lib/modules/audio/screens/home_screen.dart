import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_provider.dart';
import '../widgets/clip_list_item.dart';
import '../widgets/folder_list_item.dart';
import '../widgets/add_menu.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Provider'ı initialize et
    Future.microtask(() {
      ref.read(audioProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _renameFolder(Folder folder) async {
    final controller = TextEditingController(text: folder.name);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Klasörü Yeniden Adlandır'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Yeni İsim',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(audioProvider.notifier)
                    .renameFolder(folder, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);

    return audioState.when(
      data: (state) => _buildContent(context, state),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Hata: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AudioState state) {
    final currentFolder = state.currentFolderId != null
        ? state.folders
            .firstWhere((folder) => folder.id == state.currentFolderId)
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: currentFolder != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    ref.read(audioProvider.notifier).setCurrentFolder(null),
              )
            : null,
        title: Text(currentFolder?.name ?? 'Ses Kliplerim'),
      ),
      body: CustomScrollView(
        slivers: [
          // Arama Çubuğu
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Ara...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) =>
                    ref.read(audioProvider.notifier).search(value),
              ),
            ),
          ),

          // Klasörler Başlığı ve Listesi
          if (currentFolder == null && state.folders.isNotEmpty) ...[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Klasörler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => FolderListItem(
                    folder: state.folders[index],
                    onTap: () => ref
                        .read(audioProvider.notifier)
                        .setCurrentFolder(state.folders[index].id),
                    onRename: () => _renameFolder(state.folders[index]),
                  ),
                  childCount: state.folders.length,
                ),
              ),
            ),
          ],

          // Klipler Başlığı
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Klipler',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Klipler Listesi
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: currentFolder != null
                ? _buildClipsList(state.currentFolderClips)
                : _buildClipsList(state.rootClips),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildClipsList(List<AudioClip> clips) {
    if (clips.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.audio_file, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Henüz klip eklenmemiş'),
              Text('Eklemek için + butonuna tıklayın'),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => ClipListItem(
          clip: clips[index],
          onShare: () =>
              ref.read(audioProvider.notifier).shareClip(clips[index]),
        ),
        childCount: clips.length,
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet<bool>(
      context: context,
      builder: (context) => const AddMenu(),
    );
  }
}
