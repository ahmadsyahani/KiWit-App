import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/saved_inspection.dart';

abstract interface class InspectionLocalStorage {
  Future<List<SavedInspection>> load();
  Future<void> write(List<SavedInspection> records);
  Future<String> preservePhoto(String id, String sourcePath);
}

/// Recovery is opt-in: a controller must never overwrite an unreadable store
/// unless that store has preserved the original and salvaged readable records.
abstract interface class RecoverableInspectionStorage {
  String? get recoveryIssue;
  Future<List<SavedInspection>> recover();
}

class FileInspectionStorage
    implements InspectionLocalStorage, RecoverableInspectionStorage {
  FileInspectionStorage(
    this.ownerId, {
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final String ownerId;
  final Future<Directory> Function() _documentsDirectory;
  @override
  String? recoveryIssue;

  Future<Directory> _directory() async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(ownerId)) {
      throw const FormatException('Identitas penyimpanan tidak valid.');
    }
    final root = await _documentsDirectory();
    final directory = Directory('${root.path}/inspections_v1/$ownerId');
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<List<SavedInspection>> load() async {
    final directory = await _directory();
    final notice = File('${directory.path}/recovery-notice.txt');
    if (await notice.exists()) recoveryIssue = await notice.readAsString();
    final file = File('${directory.path}/records.json');
    if (!await file.exists()) return [];
    final document =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (document['version'] != 1) {
      throw const FormatException('Versi data inspeksi tidak didukung.');
    }
    final records = (document['records'] as List)
        .map(
          (item) =>
              SavedInspection.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    if (records.any((record) => record.ownerId != ownerId)) {
      throw const FormatException('Data inspeksi tidak sesuai akun.');
    }
    return records;
  }

  @override
  Future<List<SavedInspection>> recover() async {
    final directory = await _directory();
    final file = File('${directory.path}/records.json');
    // Read and back up before replacing anything. Read/copy failures must abort.
    final bytes = await file.readAsBytes();
    Object? document;
    try {
      document = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      // Invalid JSON is preserved in full; readable cloud data can still return.
    }
    final version = document is Map ? document['version'] : null;
    if (version is num && version != 1) {
      throw const FormatException('Versi data inspeksi tidak didukung.');
    }
    final backup = File(
      '${directory.path}/records.recovery.${DateTime.now().microsecondsSinceEpoch}.json',
    );
    await backup.writeAsBytes(bytes, flush: true);
    final recovered = <SavedInspection>[];
    if (document is Map && version == 1 && document['records'] is List) {
      for (final item in document['records'] as List) {
        try {
          final record = SavedInspection.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
          if (record.ownerId == ownerId) recovered.add(record);
        } catch (_) {
          // Unreadable records remain intact in the original backup.
        }
      }
    }
    const issue =
        'Data lokal bermasalah telah dicadangkan. Data yang dapat dibaca tetap tersedia; '
        'sebagian inspeksi lama mungkin memerlukan pemulihan dari salinan cadangan.';
    await File(
      '${directory.path}/recovery-notice.txt',
    ).writeAsString(issue, flush: true);
    await write(recovered);
    recoveryIssue = issue;
    return recovered;
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
