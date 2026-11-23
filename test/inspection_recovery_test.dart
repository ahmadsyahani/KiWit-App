import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiwit_app/features/scan/data/models/saved_inspection.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_controller.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_local_storage.dart';

import 'inspection_sync_test.dart'
    show MemoryLocal, MemoryRemote, owner, recordAt;

class SelectiveRemote extends MemoryRemote {
  bool brokenPhoto = true;
  int fetchCalls = 0;
  @override
  Future<SavedInspection> push(SavedInspection record) async {
    if (record.id == 'broken' && brokenPhoto) {
      throw const FileSystemException('Missing photo');
    }
    return super.push(record);
  }

  @override
  Future<List<SavedInspection>> fetchAll() async {
    fetchCalls++;
    return super.fetchAll();
  }
}

void main() {
  test(
    'one failed photo cannot starve later uploads or cloud downloads; retry clears its issue',
    () async {
      final local = MemoryLocal([
        recordAt('broken', DateTime(2026, 10, 20), synced: false),
        recordAt('good', DateTime(2026, 10, 19), synced: false),
      ]);
      final remote = SelectiveRemote();
      remote.records['other-device'] = recordAt(
        'other-device',
        DateTime(2026, 10, 18),
      );
      final controller = InspectionController(
        ownerId: owner,
        local: local,
        remote: remote,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(remote.successfulPushes, ['good']);
      expect(remote.fetchCalls, greaterThan(0));
      expect(controller.state.requireValue.records.map((r) => r.id).toSet(), {
        'broken',
        'good',
        'other-device',
      });
      expect(controller.state.requireValue.pendingCount, 1);
      expect(
        controller.state.requireValue.recordSyncIssues['broken'],
        contains('Foto lokal'),
      );
      remote.brokenPhoto = false;
      await controller.refresh();
      expect(controller.state.requireValue.pendingCount, 0);
      expect(controller.state.requireValue.recordSyncIssues, isEmpty);
      expect(controller.state.requireValue.syncIssue, isNull);
      expect(remote.successfulPushes, ['good', 'broken']);
    },
  );

  late Directory root;
  late FileInspectionStorage storage;
  late File records;
  setUp(() async {
    final base = await Directory(
      'build/recovery-tests',
    ).create(recursive: true);
    root = await base.createTemp('case-');
    storage = FileInspectionStorage(
      owner,
      documentsDirectory: () async => root,
    );
    final dir = await Directory(
      '${root.path}/inspections_v1/$owner',
    ).create(recursive: true);
    records = File('${dir.path}/records.json');
  });
  tearDown(() async {
    final base = Directory('build/recovery-tests').absolute.path;
    final target = root.absolute.path;
    if (!target.startsWith('$base${Platform.pathSeparator}')) {
      throw StateError('Unexpected test cleanup path');
    }
    await root.delete(recursive: true);
  });

  test(
    'invalid JSON is backed up byte for byte before cloud recovery and new local saves',
    () async {
      const bytes = [123, 34, 98, 114, 111, 107, 101, 110, 255];
      await records.writeAsBytes(bytes);
      final remote = MemoryRemote();
      remote.records['cloud'] = recordAt('cloud', DateTime(2026));
      final controller = InspectionController(
        ownerId: owner,
        local: storage,
        remote: remote,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      final backups = await records.parent
          .list()
          .where((e) => e.path.contains('records.recovery.'))
          .toList();
      expect(await File(backups.single.path).readAsBytes(), bytes);
      expect(controller.state.requireValue.records.single.id, 'cloud');
      expect(controller.state.requireValue.recoveryIssue, isNotNull);
      expect(controller.state.requireValue.syncIssue, isNull);
      final photo = await File(
        '${root.path}/photo.jpg',
      ).writeAsBytes([1, 2, 3]);
      await controller.save(
        data: recordAt(
          'new',
          DateTime(2026, 10),
        ).data.copyWith(imagePath: photo.path),
        notes: '',
        inspectorName: '',
        rayon: '',
      );
      await controller.refresh();
      expect(controller.state.requireValue.records.length, 2);
      final reopened = FileInspectionStorage(
        owner,
        documentsDirectory: () async => root,
      );
      expect((await reopened.load()).length, 2);
      expect(reopened.recoveryIssue, isNotNull);
    },
  );

  test(
    'partial recovery preserves pending data offline and excludes unreadable and foreign records',
    () async {
      final pending = recordAt('pending', DateTime(2026), synced: false);
      final original = jsonEncode({
        'version': 1,
        'records': [
          pending.toJson(),
          {'bad': 'record'},
          recordAt('foreign', DateTime(2026), userId: 'other').toJson(),
        ],
      });
      await records.writeAsString(original);
      final remote = MemoryRemote()..connected = false;
      final controller = InspectionController(
        ownerId: owner,
        local: storage,
        remote: remote,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.state.requireValue.records.single.id, 'pending');
      expect(controller.state.requireValue.pendingCount, 1);
      final backup =
          (await records.parent
                  .list()
                  .where((e) => e.path.contains('records.recovery.'))
                  .toList())
              .single;
      expect(await File(backup.path).readAsString(), original);
      remote.connected = true;
      await controller.refresh();
      expect(remote.records.keys, ['pending']);
    },
  );

  test(
    'unsupported storage version leaves the active file intact and blocks sync',
    () async {
      final original = jsonEncode({
        'version': 2,
        'records': [
          recordAt('pending', DateTime(2026), synced: false).toJson(),
        ],
      });
      await records.writeAsString(original);
      final remote = SelectiveRemote();
      final controller = InspectionController(
        ownerId: owner,
        local: storage,
        remote: remote,
      );
      addTearDown(controller.dispose);

      await expectLater(controller.refresh(), throwsA(isA<FormatException>()));
      expect(controller.state.hasError, isTrue);
      expect(await records.readAsString(), original);
      expect(remote.fetchCalls, 0);
    },
  );

  test(
    'failed backup never overwrites original or starts cloud recovery',
    () async {
      await records.writeAsString('broken');
      final blocked = NoBackupStorage(owner, root);
      final remote = SelectiveRemote();
      final controller = InspectionController(
        ownerId: owner,
        local: blocked,
        remote: remote,
      );
      addTearDown(controller.dispose);
      await expectLater(
        controller.refresh(),
        throwsA(isA<FileSystemException>()),
      );
      expect(await records.readAsString(), 'broken');
      expect(remote.fetchCalls, 0);
    },
  );
}

class NoBackupStorage extends FileInspectionStorage {
  NoBackupStorage(super.ownerId, Directory root)
    : super(documentsDirectory: () async => root);
  @override
  Future<List<SavedInspection>> recover() async =>
      throw const FileSystemException('Backup denied');
}
