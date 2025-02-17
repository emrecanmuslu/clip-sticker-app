import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AudioFileHandler {
  static Future<String> prepareAudioFile(String sourceFile) async {
    try {
      // Ses dosyasını geçici dizine kopyala
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(sourceFile);
      final preparedPath = path.join(tempDir.path, 'prepared_$fileName');

      // Orijinal dosyayı geçici konuma kopyala
      await File(sourceFile).copy(preparedPath);

      return preparedPath;
    } catch (e) {
      throw Exception('Ses dosyası hazırlanamadı: $e');
    }
  }

  static Future<void> cleanupTempFile(String? filePath) async {
    if (filePath != null) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Geçici dosya temizleme hatası: $e');
      }
    }
  }
}