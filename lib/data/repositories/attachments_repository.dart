import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/data_bus.dart';
import '../../core/utils/ids.dart';
import '../models/attachment.dart';
import '../models/sync_tombstone.dart';
import '../services/attachment_storage.dart';

class AttachmentsRepository {
  AttachmentsRepository(this._isar, this._storage);

  final Isar _isar;
  final AttachmentStorage _storage;

  Stream<List<Attachment>> watchForNote(int noteId) => watchLive(
        changes: [_isar.attachments.watchLazy(), DataBus.stream],
        snapshot: () => _isar.attachments
            .filter()
            .noteIdEqualTo(noteId)
            .sortByCreatedAtDesc()
            .findAll(),
      );

  Future<List<Attachment>> listForNote(int noteId) =>
      _isar.attachments.filter().noteIdEqualTo(noteId).findAll();

  Future<Attachment> importForNote(int noteId, File source) async {
    final stored = await _storage.import(source);
    final att = Attachment()
      ..syncId = newUuid()
      ..noteId = noteId
      ..storedPath = stored.relativePath
      ..fileName = p.basename(source.path)
      ..mimeType = stored.mimeType
      ..sizeBytes = stored.sizeBytes
      ..createdAt = DateTime.now();
    final id = await _isar.writeTxn(() => _isar.attachments.put(att));
    DataBus.ping();
    return (await _isar.attachments.get(id))!;
  }

  Future<void> delete(Attachment att) async {
    if (att.syncId.isNotEmpty) {
      await _isar.writeTxn(
        () => _isar.syncTombstones.put(
          SyncTombstone()
            ..key = 'attachment:${att.syncId}'
            ..collection = 'attachment'
            ..uuid = att.syncId
            ..deletedAt = DateTime.now(),
        ),
      );
    }
    await _storage.deleteRelative(att.storedPath);
    await _isar.writeTxn(() => _isar.attachments.delete(att.id));
    DataBus.ping();
  }

  Future<void> deleteAllOfNote(int noteId) async {
    final items = await listForNote(noteId);
    for (final a in items) {
      await _storage.deleteRelative(a.storedPath);
    }
    await _isar.writeTxn(() async {
      for (final a in items) {
        if (a.syncId.isEmpty) continue;
        await _isar.syncTombstones.put(
          SyncTombstone()
            ..key = 'attachment:${a.syncId}'
            ..collection = 'attachment'
            ..uuid = a.syncId
            ..deletedAt = DateTime.now(),
        );
      }
      final ids = items.map((a) => a.id).toList();
      await _isar.attachments.deleteAll(ids);
    });
    DataBus.ping();
  }

  File resolveFile(Attachment att) => _storage.resolve(att.storedPath);
}
