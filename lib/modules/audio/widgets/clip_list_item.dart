import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../shared/providers/audio_player_provider.dart';
import '../providers/audio_provider.dart';

class ClipListItem extends ConsumerStatefulWidget {
  final AudioClip clip;
  final VoidCallback onShare;

  const ClipListItem({
    super.key,
    required this.clip,
    required this.onShare,
  });

  @override
  ConsumerState<ClipListItem> createState() => _ClipListItemState();
}

class _ClipListItemState extends ConsumerState<ClipListItem> {
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Consumer(
        builder: (context, ref, child) {
          return StreamBuilder<bool>(
            stream: ref.watch(audioPlayerProvider.notifier).playingStream,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              final isCurrentClip =
                  ref.watch(audioPlayerProvider.notifier).currentPath ==
                      widget.clip.path;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: IconButton(
                      icon: Icon(
                        (isPlaying && isCurrentClip)
                            ? Icons.pause_circle
                            : Icons.play_circle,
                        color: Theme.of(context).primaryColor,
                        size: 32,
                      ),
                      onPressed: () {
                        final audioPlayerNotifier =
                            ref.read(audioPlayerProvider.notifier);
                        if (isPlaying && isCurrentClip) {
                          audioPlayerNotifier.pause();
                        } else {
                          audioPlayerNotifier.playClip(widget.clip.path);
                        }
                      },
                    ),
                    title: Text(
                      widget.clip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatDuration(
                          Duration(seconds: widget.clip.duration.toInt())),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: widget.onShare,
                        ),
                        PopupMenuButton<String>(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit),
                                  SizedBox(width: 8),
                                  Text('Yeniden Adlandır'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'move',
                              child: Row(
                                children: [
                                  Icon(Icons.folder),
                                  SizedBox(width: 8),
                                  Text('Taşı'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Sil',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            switch (value) {
                              case 'rename':
                                await _showRenameDialog(context, ref);
                                break;
                              case 'move':
                                await _showMoveDialog(context, ref);
                                break;
                              case 'delete':
                                await _showDeleteDialog(context, ref);
                                break;
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (isPlaying && isCurrentClip)
                    StreamBuilder<Duration?>(
                      stream: ref
                          .watch(audioPlayerProvider.notifier)
                          .positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final duration =
                            Duration(seconds: widget.clip.duration.toInt());
                        return LinearProgressIndicator(
                          value: duration.inMilliseconds > 0
                              ? position.inMilliseconds /
                                  duration.inMilliseconds
                              : 0.0,
                          backgroundColor:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor),
                          minHeight: 2,
                        );
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: widget.clip.name);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeniden Adlandır'),
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
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await ref
                    .read(audioProvider.notifier)
                    .renameClip(widget.clip, controller.text);
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMoveDialog(BuildContext context, WidgetRef ref) async {
    final currentState = ref.read(audioProvider).value;
    if (currentState == null) return;

    final currentFolderId = widget.clip.folderId;

    return showDialog(
      context: context,
      builder: (context) => Dialog(
        child: DefaultTabController(
          length: 2,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Nereye Taşımak İstersiniz?',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      TabBar(
                        indicatorColor: Colors.white,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Ana Klasör', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Alt Klasörler', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: TabBarView(
                    children: [
                      // Ana Klasör Sekmesi
                      _buildMainFolderTab(context, ref),

                      // Alt Klasörler Sekmesi
                      _buildSubFoldersTab(
                        context,
                        ref,
                        currentState.folders,
                        currentFolderId,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainFolderTab(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.drive_folder_upload,
            size: 64,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          Text(
            'Ana Klasöre Taşı',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tüm kliplerinize ana klasörden kolayca erişebilirsiniz.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await ref
                  .read(audioProvider.notifier)
                  .moveClipToFolder(widget.clip, null);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${widget.clip.name} ana klasöre taşındı'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Ana Klasöre Taşı'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubFoldersTab(
    BuildContext context,
    WidgetRef ref,
    List<Folder> folders,
    String? currentFolderId,
  ) {
    final filteredFolders =
        folders.where((folder) => folder.id != currentFolderId).toList();

    if (filteredFolders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Henüz klasör bulunmuyor',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Yeni bir klasör oluşturmak için ana sayfadaki + butonunu kullanabilirsiniz.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredFolders.length,
      itemBuilder: (context, index) {
        final folder = filteredFolders[index];
        return ListTile(
          leading: const Icon(Icons.folder, color: Colors.blue),
          title: Text(folder.name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await ref
                .read(audioProvider.notifier)
                .moveClipToFolder(widget.clip, folder.id);
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${widget.clip.name}, ${folder.name} klasörüne taşındı'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ses Klibini Sil'),
        content:
            const Text('Bu ses klibini silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(audioProvider.notifier).deleteClip(widget.clip);
    }
  }
}
