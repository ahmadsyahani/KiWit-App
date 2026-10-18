import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'notification_entry.dart';

abstract interface class NotificationStorage {
  Future<List<NotificationEntry>> load();
  Future<void> write(List<NotificationEntry> entries);
}

class FileNotificationStorage implements NotificationStorage {
  FileNotificationStorage(this.ownerId, {
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;
  final String ownerId;
  final Future<Directory> Function() _documentsDirectory;

  Future<File> _file() async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(ownerId)) {
      throw const FormatException('Identitas akun tidak valid.');
    }
    final root = await _documentsDirectory();
    final directory = Directory('${root.path}/notifications_v1/$ownerId');
    await directory.create(recursive: true);
    return File('${directory.path}/inbox.json');
  }

  @override
  Future<List<NotificationEntry>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    final document = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (document['version'] != 1 || document['ownerId'] != ownerId) {
      throw const FormatException('Data notifikasi tidak sesuai akun.');
    }
    return (document['entries'] as List).map((item) =>
      NotificationEntry.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  @override
  Future<void> write(List<NotificationEntry> entries) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode({
      'version': 1, 'ownerId': ownerId,
      'entries': entries.map((entry) => entry.toJson()).toList(),
    }), flush: true);
    await temporary.rename(file.path);
  }
}
