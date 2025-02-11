import 'package:flutter/material.dart';
import '../providers/audio_provider.dart';

class FolderListItem extends StatelessWidget {
  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback onRename;

  const FolderListItem({
    super.key,
    required this.folder,
    required this.onTap,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.folder),
        title: Text(
          folder.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
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
          onSelected: (value) {
            switch (value) {
              case 'rename':
                _showRenameDialog(context);
                break;
              case 'delete':
                _showDeleteDialog(context);
                break;
            }
          },
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
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
              onRename();
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Klasörü Sil'),
        content: const Text(
          'Bu klasörü silmek istediğinizden emin misiniz?\nKlasör içindeki tüm ses klipleri taşınacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              // Silme işlemi
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}