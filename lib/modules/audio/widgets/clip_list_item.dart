import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../shared/providers/audio_player_provider.dart';
import '../providers/audio_provider.dart';

class ClipListItem extends ConsumerWidget {
  final AudioClip clip;
  final VoidCallback onShare;

  const ClipListItem({
    super.key,
    required this.clip,
    required this.onShare,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(audioPlayerProvider);
    final currentPath = ref.watch(audioPlayerProvider.notifier).currentPath;
    final isCurrentClip = currentPath == clip.path;

    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final isPlaying = isCurrentClip && playerState?.playing == true;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_circle : Icons.play_circle,
                color: Theme.of(context).primaryColor,
                size: 32,
              ),
              onPressed: () {
                ref.read(audioPlayerProvider.notifier).playClip(clip.path);
              },
            ),
            title: Text(
              clip.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _formatDuration(Duration(seconds: clip.duration.toInt())),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: onShare,
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
                          Text('Sil', style: TextStyle(color: Colors.red)),
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
        );
      },
    );
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: clip.name);
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
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(audioProvider.notifier)
                    .renameClip(clip, controller.text);
              }
              Navigator.pop(context);
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

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Klasöre Taşı'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Ana Klasör'),
                onTap: () {
                  ref.read(audioProvider.notifier).moveClipToFolder(clip, null);
                  Navigator.pop(context);
                },
              ),
              ...currentState.folders.map((folder) => ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(folder.name),
                    onTap: () {
                      ref
                          .read(audioProvider.notifier)
                          .moveClipToFolder(clip, folder.id);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
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
      await ref.read(audioProvider.notifier).deleteClip(clip);
    }
  }
}
