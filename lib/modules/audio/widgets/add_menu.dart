import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_provider.dart';
import '../screens/clip_editor_screen.dart';

class AddMenu extends ConsumerWidget {
  const AddMenu({super.key});

  Future<void> _pickAudioFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        if (!context.mounted) return;

        final currentState = ref.read(audioProvider).value;
        final currentFolderId = currentState?.currentFolderId;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClipEditorScreen(
              audioPath: result.files.single.path!,
              folderId: currentFolderId,
            ),
          ),
        );

        if (context.mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya seçme hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        final audioState = ref.watch(audioProvider);

        return audioState.when(
          data: (state) => Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Yeni Ekle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Sadece ana klasördeyken klasör oluşturma seçeneğini göster
                if (state.currentFolderId == null)
                  ListTile(
                    leading: const Icon(Icons.create_new_folder),
                    title: const Text('Yeni Klasör'),
                    onTap: () {
                      Navigator.pop(context);
                      _showNewFolderDialog(context);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.audio_file),
                  title: const Text('MP3 Seç'),
                  onTap: () => _pickAudioFile(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.youtube_searched_for),
                  title: const Text("YouTube'dan İndir"),
                  onTap: () {
                    Navigator.pop(context);
                    // YouTube arama ekranına git
                  },
                ),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Hata: $error')),
        );
      },
    );
  }

  Future<void> _showNewFolderDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Klasör'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Klasör Adı',
            hintText: 'Klasör adını girin',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          Consumer(
            builder: (context, ref, child) => TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await ref
                      .read(audioProvider.notifier)
                      .createFolder(controller.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Oluştur'),
            ),
          ),
        ],
      ),
    );
  }
}
