import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/saved_inspection.dart';

abstract interface class InspectionLocalStorage {
  Future<List<SavedInspection>> load();
  Future<void> write(List<SavedInspection> records);
  Future<String> preservePhoto(String id, String sourcePath);
}

class FileInspectionStorage implements InspectionLocalStorage {
  FileInspectionStorage(this.ownerId);

  final String ownerId;

  Future<Directory> _directory() async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(ownerId)) {
      throw const FormatException('Identitas penyimpanan tidak valid.');
    }
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/inspections_v1/$ownerId');
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<List<SavedInspection>> load() async {
    final directory = await _directory();
    final file = File('${directory.path}/records.json');
    if (!await file.exists()) return [];
    final document = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (document['version'] != 1) {
      throw const FormatException('Versi data inspeksi tidak didukung.');
    }
    final records = (document['records'] as List)
        .map((item) => SavedInspection.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    if (records.any((record) => record.ownerId != ownerId)) {
      throw const FormatException('Data inspeksi tidak sesuai akun.');
    }
    return records;
  }

  @override
  Future<void> write(List<SavedInspection> records) async {
    final directory = await _directory();
    final temporary = File('${directory.path}/records.json.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'version': 1,
        'records': records.map((record) => record.toJson()).toList(),
      }),
      flush: true,
    );
    await temporary.rename('${directory.path}/records.json');
  }

  @override
  Future<String> preservePhoto(String id, String sourcePath) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Identitas foto tidak valid.');
    }
    final directory = await _directory();
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('Foto inspeksi tidak ditemukan.');
    }
    final destination = '${directory.path}/$id.jpg';
    if (source.path == destination) return source.path;
    return (await source.copy(destination)).path;
  }
}
