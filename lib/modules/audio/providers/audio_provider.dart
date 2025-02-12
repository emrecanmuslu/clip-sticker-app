import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

// Ses Klibi Modeli
class AudioClip {
  final String id;
  final String name;
  final String path;
  final String? folderId;
  final DateTime createdAt;
  final double duration;

  AudioClip({
    required this.id,
    required this.name,
    required this.path,
    this.folderId,
    required this.duration,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AudioClip copyWith({
    String? name,
    String? path,
    String? folderId,
    double? duration,
  }) {
    return AudioClip(
      id: id,
      name: name ?? this.name,
      path: path ?? this.path,
      folderId: folderId ?? this.folderId,
      duration: duration ?? this.duration,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'folderId': folderId,
        'createdAt': createdAt.toIso8601String(),
        'duration': duration,
      };

  static AudioClip fromJson(Map<String, dynamic> json) => AudioClip(
        id: json['id'],
        name: json['name'],
        path: json['path'],
        folderId: json['folderId'],
        duration: json['duration'] ?? 0.0,
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class Folder {
  final String id;
  final String name;
  final DateTime createdAt;

  Folder({
    required this.id,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  static Folder fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'],
        name: json['name'],
        createdAt: DateTime.parse(json['createdAt']),
      );

  Folder copyWith({String? name}) {
    return Folder(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
    );
  }
}

class AudioState {
  final List<AudioClip> clips;
  final List<Folder> folders;
  final String? currentFolderId;
  final String? searchQuery;

  AudioState({
    this.clips = const [],
    this.folders = const [],
    this.currentFolderId,
    this.searchQuery,
  });

  List<AudioClip> get currentFolderClips {
    return clips.where((clip) {
      if (searchQuery?.isNotEmpty ?? false) {
        return clip.name.toLowerCase().contains(searchQuery!.toLowerCase()) &&
            clip.folderId == currentFolderId;
      }
      return clip.folderId == currentFolderId;
    }).toList();
  }

  List<AudioClip> get rootClips {
    return clips.where((clip) {
      if (searchQuery?.isNotEmpty ?? false) {
        return clip.name.toLowerCase().contains(searchQuery!.toLowerCase()) &&
            clip.folderId == null;
      }
      return clip.folderId == null;
    }).toList();
  }

  AudioState copyWith({
    List<AudioClip>? clips,
    List<Folder>? folders,
    String? currentFolderId,
    String? searchQuery,
  }) {
    return AudioState(
      clips: clips ?? this.clips,
      folders: folders ?? this.folders,
      currentFolderId: currentFolderId,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class AudioNotifier extends StateNotifier<AsyncValue<AudioState>> {
  static const String _prefsKey = 'audio_data';

  AudioNotifier() : super(const AsyncValue.loading());

  Future<void> initialize() async {
    try {
      if (!await _checkPermissions()) {
        throw Exception('Gerekli izinler verilmedi');
      }

      await _loadFromPrefs();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.audio.request().isGranted) return true;
      if (await Permission.storage.request().isGranted) return true;
      return false;
    }
    return true;
  }

  Future<void> _saveToPrefs(List<Folder> folders, List<AudioClip> clips) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'folders': folders.map((f) => f.toJson()).toList(),
      'clips': clips.map((c) => c.toJson()).toList(),
    };
    await prefs.setString(_prefsKey, json.encode(data));
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_prefsKey);

    if (dataString != null) {
      final data = json.decode(dataString);
      final folders =
          (data['folders'] as List).map((f) => Folder.fromJson(f)).toList();
      final clips =
          (data['clips'] as List).map((c) => AudioClip.fromJson(c)).toList();

      state = AsyncValue.data(AudioState(
        folders: folders,
        clips: clips,
      ));
    } else {
      state = AsyncValue.data(AudioState());
    }
  }

  Future<void> addClip(File file,
      {String? folderId,
      double? duration,
      String? customName,
      bool keepFolderId = false}) async {
    try {
      final currentState = state.value!;

      final randomFileName = '${DateTime.now().millisecondsSinceEpoch}.mp3';
      final appDir = await getApplicationDocumentsDirectory();
      final newPath = '${appDir.path}/audios/$randomFileName';

      final audioDir = Directory('${appDir.path}/audios');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      await file.copy(newPath);

      final newClip = AudioClip(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: customName ?? file.path.split('/').last,
        path: newPath,
        folderId: folderId,
        duration: duration ?? 0,
      );

      final updatedClips = [...currentState.clips, newClip];
      await _saveToPrefs(currentState.folders, updatedClips);

      state = AsyncValue.data(currentState.copyWith(
          clips: updatedClips,
          currentFolderId: keepFolderId ? currentState.currentFolderId : null));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteClip(AudioClip clip) async {
    try {
      final currentState = state.value!;
      final currentFolderId = currentState.currentFolderId;

      final file = File(clip.path);
      if (await file.exists()) {
        await file.delete();
      }

      final updatedClips =
          currentState.clips.where((c) => c.id != clip.id).toList();
      await _saveToPrefs(currentState.folders, updatedClips);

      state = AsyncValue.data(currentState.copyWith(
          clips: updatedClips,
          currentFolderId: currentFolderId // Mevcut klasör bilgisini koru
          ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> renameClip(AudioClip clip, String newName) async {
    try {
      final currentState = state.value!;
      final currentFolderId = currentState.currentFolderId;

      final updatedClips = currentState.clips.map((c) {
        if (c.id == clip.id) {
          return c.copyWith(name: newName);
        }
        return c;
      }).toList();

      await _saveToPrefs(currentState.folders, updatedClips);

      state = AsyncValue.data(currentState.copyWith(
          clips: updatedClips, currentFolderId: currentFolderId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void search(String query) {
    try {
      final currentState = state.value!;
      state = AsyncValue.data(currentState.copyWith(searchQuery: query));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> shareClip(AudioClip clip) async {
    try {
      final file = XFile(clip.path);
      await Share.shareXFiles([file], text: clip.name);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createFolder(String name) async {
    if (state.value == null) return;

    try {
      final currentState = state.value!;

      final newFolder = Folder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
      );

      final updatedFolders = [...currentState.folders, newFolder];
      await _saveToPrefs(updatedFolders, currentState.clips);

      state = AsyncValue.data(state.value!.copyWith(
        folders: updatedFolders,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteFolder(Folder folder) async {
    try {
      final currentState = state.value!;

      // Klasördeki tüm klipleri sil
      for (var clip
          in currentState.clips.where((c) => c.folderId == folder.id)) {
        final file = File(clip.path);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Klasörü ve klipleri state'den kaldır
      final updatedClips = currentState.clips
          .where((clip) => clip.folderId != folder.id)
          .toList();
      final updatedFolders =
          currentState.folders.where((f) => f.id != folder.id).toList();

      await _saveToPrefs(updatedFolders, updatedClips);

      state = AsyncValue.data(currentState.copyWith(
        folders: updatedFolders,
        clips: updatedClips,
        currentFolderId: null,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> moveClipToFolder(AudioClip clip, String? folderId) async {
    try {
      final currentState = state.value!;
      final updatedClips = currentState.clips.map((c) {
        if (c.id == clip.id) {
          return c.copyWith(folderId: folderId);
        }
        return c;
      }).toList();

      await _saveToPrefs(currentState.folders, updatedClips);
      state = AsyncValue.data(currentState.copyWith(clips: updatedClips));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> renameFolder(Folder folder, String newName) async {
    try {
      final currentState = state.value!;

      final updatedFolders = currentState.folders.map((f) {
        if (f.id == folder.id) {
          return f.copyWith(name: newName);
        }
        return f;
      }).toList();

      await _saveToPrefs(updatedFolders, currentState.clips);
      state = AsyncValue.data(currentState.copyWith(folders: updatedFolders));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void setCurrentFolder(String? folderId) {
    if (state.value == null) return;
    state = AsyncValue.data(state.value!.copyWith(currentFolderId: folderId));
  }
}

final audioProvider =
    StateNotifierProvider<AudioNotifier, AsyncValue<AudioState>>((ref) {
  return AudioNotifier();
});
