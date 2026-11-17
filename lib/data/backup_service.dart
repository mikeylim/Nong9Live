import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_store.dart';
import 'photo_store.dart';

/// Export / import of all data as one JSON file (player photos included),
/// e.g. to move to a new phone or hand scorekeeping to someone else.
class BackupService {
  static Future<Map<String, dynamic>> buildBackup(AppStore store) async {
    final json = store.toBackup();
    final photos = <String, String>{};
    for (final p in store.allPlayers) {
      final bytes = await PhotoStore.read(p.photoPath);
      if (bytes != null && p.photoPath != null) photos[p.photoPath!] = base64Encode(bytes);
    }
    json['photos'] = photos;
    return json;
  }

  static Future<void> export(AppStore store) async {
    final json = await buildBackup(store);
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${dir.path}/nong9live-backup-$stamp.json');
    await file.writeAsString(jsonEncode(json), flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: '${store.settings.crewName} backup ($stamp)',
    ));
  }

  /// Lets the user choose a backup file and returns its parsed content,
  /// or null if cancelled. Throws [FormatException] on bad files.
  static Future<Map<String, dynamic>?> pick() async {
    final file = await FilePicker.pickFile(dialogTitle: 'Choose a backup file');
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map || decoded['format'] != AppStore.backupFormat) {
      throw const FormatException('That file is not a Nong9 Live backup.');
    }
    return decoded.cast<String, dynamic>();
  }

  static Future<void> restore(AppStore store, Map<String, dynamic> json) async {
    await store.restoreBackup(json);
    final photos = (json['photos'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final e in photos.entries) {
      try {
        await PhotoStore.write(e.key, base64Decode(e.value as String));
      } catch (_) {}
    }
  }
}
