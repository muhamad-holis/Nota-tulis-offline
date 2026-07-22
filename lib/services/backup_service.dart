import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';

class BackupService {
  static Future<String> exportBackup() async {
    final db = DatabaseHelper.instance;
    final products = await db.getAllProducts();
    final notas = await db.getAllNotas();
    final settings = await db.getSettings();

    final payload = {
      'version': 1,
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
      'products': products.map((p) => p.toMap()).toList(),
      'notas': notas.map((n) => n.toBackupJson()).toList(),
      'settings': [settings.toMap()],
    };

    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = 'nota-tulis-backup-$dateStr.json';

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonEncode(payload));

    await Share.shareXFiles([XFile(file.path)], text: 'Backup Nota Tulis');
    return file.path;
  }

  /// Buka file picker, lalu timpa seluruh data lokal dengan isi file backup.
  static Future<void> importBackupFromPicker() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) {
      throw Exception('Tidak ada file dipilih.');
    }
    final file = File(result.files.single.path!);
    final text = await file.readAsString();
    final payload = jsonDecode(text) as Map<String, dynamic>;

    if (payload['products'] is! List || payload['notas'] is! List) {
      throw Exception('File backup tidak valid.');
    }

    final db = DatabaseHelper.instance;
    final products = (payload['products'] as List).cast<Map<String, dynamic>>();
    final notasRaw = (payload['notas'] as List).cast<Map<String, dynamic>>();
    final settingsRaw = (payload['settings'] as List? ?? []).cast<Map<String, dynamic>>();

    // Notas di backup pakai representasi items sebagai List<Map>, perlu di-encode
    // ulang jadi String JSON supaya cocok dengan kolom `items` di tabel SQLite.
    final notas = notasRaw.map((n) {
      final copy = Map<String, dynamic>.from(n);
      copy['items'] = jsonEncode(copy['items']);
      return copy;
    }).toList();

    await db.replaceAllProducts(products);
    await db.replaceAllNotas(notas);
    if (settingsRaw.isNotEmpty) await db.replaceAllSettings(settingsRaw);
  }
}
