import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

// Ses Klibi Modeli
class AudioClip {
  final String id;
  final String name;
  final String path;
  final String? folderId;
  final DateTime createdAt;

  AudioClip({
    required this.id,
    required this.name,
    required this.path,
    this.folderId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AudioClip copyWith({
    String? name,
    String? folderId,
  }) {
    return AudioClip(
      id: id,
      name: name ?? this.name,
      path: path,
      folderId: folderId ?? this.folderId,
      createdAt: createdAt,
    );
  }
}

// Basitleştirilmiş Klasör Modeli
class Folder {
  final String id;
  final String name;
  final DateTime createdAt;

  Folder({
    required this.id,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Folder copyWith({String? name}) {
    return Folder(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
    );
  }
}

// State Modeli
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

  // Mevcut klasördeki klipleri getir
  List<AudioClip> get currentFolderClips {
    return clips.where((clip) {
      if (searchQuery?.isNotEmpty ?? false) {
        return clip.name.toLowerCase().contains(searchQuery!.toLowerCase()) &&
            clip.folderId == currentFolderId;
      }
      return clip.folderId == currentFolderId;
    }).toList();
  }

  // Ana klasördeki (klasörsüz) klipleri getir
  List<AudioClip> get rootClips {
    return clips.where((clip) {
      if (searchQuery?.isNotEmpty ?? false) {
        return clip.name.toLowerCase().contains(searchQuery!.toLowerCase()) &&
            clip.folderId == null;
      }
      return clip.folderId == null;
    }).toList();
  }

  // Klasörleri filtrele
  List<Folder> get filteredFolders {
    if (searchQuery?.isNotEmpty ?? false) {
      return folders
          .where((folder) =>
              folder.name.toLowerCase().contains(searchQuery!.toLowerCase()))
          .toList();
    }
    return folders;
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
  AudioNotifier() : super(const AsyncValue.loading());

  Future<void> initialize() async {
    try {
      if (!await _checkPermissions()) {
        throw Exception('Gerekli izinler verilmedi');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/audios');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final files = await audioDir
          .list()
          .where((entity) => entity.path.toLowerCase().endsWith('.mp3'))
          .toList();

      final clips = files
          .map((file) => AudioClip(
                id: file.path.split('/').last.split('.').first,
                name: file.path.split('/').last,
                path: file.path,
              ))
          .toList();

      state = AsyncValue.data(AudioState(clips: clips));
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

  Future<void> addClip(File file) async {
    try {
      final currentState = state.value!;

      // Dosyayı uygulama klasörüne kopyala
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp3';
      final newPath = '${appDir.path}/audios/$fileName';
      await file.copy(newPath);

      final newClip = AudioClip(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: file.path.split('/').last,
        path: newPath,
        folderId: currentState.currentFolderId,
      );

      state = AsyncValue.data(currentState.copyWith(
        clips: [...currentState.clips, newClip],
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteClip(AudioClip clip) async {
    try {
      final currentState = state.value!;

      // Dosyayı sil
      final file = File(clip.path);
      if (await file.exists()) {
        await file.delete();
      }

      state = AsyncValue.data(currentState.copyWith(
        clips: currentState.clips.where((c) => c.id != clip.id).toList(),
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> renameClip(AudioClip clip, String newName) async {
    try {
      final currentState = state.value!;

      final updatedClips = currentState.clips.map((c) {
        if (c.id == clip.id) {
          return c.copyWith(name: newName);
        }
        return c;
      }).toList();

      state = AsyncValue.data(currentState.copyWith(clips: updatedClips));
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

  // Klasör oluştur
  Future<void> createFolder(String name) async {
    if (state.value == null) return;

    try {
      final newFolder = Folder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
      );

      state = AsyncValue.data(state.value!.copyWith(
        folders: [...state.value!.folders, newFolder],
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // Klasör sil
  Future<void> deleteFolder(Folder folder) async {
    if (state.value == null) return;

    try {
      // Klasördeki klipleri ana klasöre taşı
      final updatedClips = state.value!.clips.map((clip) {
        if (clip.folderId == folder.id) {
          return clip.copyWith(folderId: null);
        }
        return clip;
      }).toList();

      state = AsyncValue.data(state.value!.copyWith(
        folders: state.value!.folders.where((f) => f.id != folder.id).toList(),
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

      state = AsyncValue.data(currentState.copyWith(folders: updatedFolders));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // Klasör seç
  void setCurrentFolder(String? folderId) {
    if (state.value == null) return;
    state = AsyncValue.data(state.value!.copyWith(currentFolderId: folderId));
  }
}

final audioProvider =
    StateNotifierProvider<AudioNotifier, AsyncValue<AudioState>>((ref) {
  return AudioNotifier();
});
