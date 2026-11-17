import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Player photos live in the app documents `photos` folder. Players store only the file
/// name, because absolute app paths can change between app updates on iOS.
class PhotoStore {
  static Directory? _dir;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/photos');
      await dir.create(recursive: true);
      _dir = dir;
    } catch (e) {
      debugPrint('photo dir: $e');
    }
  }

  /// For tests.
  static void useDirectory(Directory dir) => _dir = dir;

  static File? fileFor(String? name) {
    if (name == null || _dir == null) return null;
    final f = File('${_dir!.path}/$name');
    return f.existsSync() ? f : null;
  }

  static Future<String?> pick(ImageSource source, String playerId) async {
    if (_dir == null) return null;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return null;
    final name = '${playerId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy('${_dir!.path}/$name');
    return name;
  }

  static Future<void> delete(String? name) async {
    final f = fileFor(name);
    if (f != null) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  static Future<Uint8List?> read(String? name) async => fileFor(name)?.readAsBytes();

  static Future<void> write(String name, List<int> bytes) async {
    if (_dir == null) return;
    await File('${_dir!.path}/$name').writeAsBytes(bytes, flush: true);
  }
}
