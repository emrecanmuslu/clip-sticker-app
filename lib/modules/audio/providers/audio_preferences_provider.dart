import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AudioProviderWithPrefs {
  static const String _folderKey = 'app_folders';
  static const String _rootClipsKey = 'root_clips';

  Future<void> saveFolders(List<Map<String, dynamic>> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_folderKey, json.encode(folders));
  }

  Future<List<Map<String, dynamic>>> getFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getString(_folderKey);
    return foldersJson != null
        ? List<Map<String, dynamic>>.from(json.decode(foldersJson))
        : [];
  }

  Future<void> addFolder(String name) async {
    final folders = await getFolders();
    folders.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'clips': []
    });
    await saveFolders(folders);
  }

  Future<void> addClip(Map<String, dynamic> clip, {String? folderId}) async {
    final folders = await getFolders();

    if (folderId == null) {
      // Root klip ekleme
      final rootClips = await getRootClips();
      rootClips.add(clip);
      await saveRootClips(rootClips);
    } else {
      // Klasöre klip ekleme
      final folderIndex = folders.indexWhere((f) => f['id'] == folderId);
      if (folderIndex != -1) {
        folders[folderIndex]['clips'].add(clip);
        await saveFolders(folders);
      }
    }
  }

  Future<void> saveRootClips(List<Map<String, dynamic>> clips) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rootClipsKey, json.encode(clips));
  }

  Future<List<Map<String, dynamic>>> getRootClips() async {
    final prefs = await SharedPreferences.getInstance();
    final clipsJson = prefs.getString(_rootClipsKey);
    return clipsJson != null
        ? List<Map<String, dynamic>>.from(json.decode(clipsJson))
        : [];
  }

  Future<List<Map<String, dynamic>>> searchClips(String query) async {
    final rootClips = await getRootClips();
    final folders = await getFolders();

    final allClips = [
      ...rootClips,
      ...folders
          .expand((folder) => List<Map<String, dynamic>>.from(folder['clips']))
    ];

    return allClips
        .where((clip) => (clip['name'] as String)
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
  }
}
