import 'package:isar_community/isar.dart';

import '../../core/utils/ids.dart';
import '../models/attachment.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/sync_tombstone.dart';
import '../models/tag.dart';

/// Owns sync identity (syncId backfill) and deletion tombstones.
class SyncRepository {
  SyncRepository(this._isar);

  final Isar _isar;

  /// Assigns uuids to any record that lacks one. Called at startup so
  /// pre-sync data becomes syncable.
  Future<void> ensureSyncIds() async {
    await _isar.writeTxn(() async {
      final notes = await _isar.notes.filter().syncIdEqualTo('').findAll();
      for (final n in notes) {
        n.syncId = newUuid();
        await _isar.notes.put(n);
      }
      final folders = await _isar.noteFolders
          .filter()
          .syncIdEqualTo('')
          .findAll();
      for (final f in folders) {
        f.syncId = newUuid();
        await _isar.noteFolders.put(f);
      }
      final tags = await _isar.tags.filter().syncIdEqualTo('').findAll();
      for (final t in tags) {
        t.syncId = newUuid();
        await _isar.tags.put(t);
      }
      final atts = await _isar.attachments.filter().syncIdEqualTo('').findAll();
      for (final a in atts) {
        a.syncId = newUuid();
        await _isar.attachments.put(a);
      }
    });
  }

  /// Records deletions so peers remove their copies on next exchange.
  Future<void> addTombstones(String collection, Iterable<String> uuids) async {
    final now = DateTime.now();
    await _isar.writeTxn(() async {
      for (final uuid in uuids) {
        if (uuid.isEmpty) continue;
        final key = '$collection:$uuid';
        final existing = await _isar.syncTombstones
            .filter()
            .keyEqualTo(key)
            .findFirst();
        final t = existing ?? (SyncTombstone()..key = key)
          ..collection = collection
          ..uuid = uuid
          ..deletedAt = now;
        await _isar.syncTombstones.put(t);
      }
    });
  }

  Future<List<SyncTombstone>> allTombstones() =>
      _isar.syncTombstones.where().findAll();

  /// Drops tombstones older than [cutoff] — safe once every peer has seen
  /// them (30 days is far beyond any realistic absence).
  Future<int> pruneTombstones(DateTime cutoff) async {
    final old = await _isar.syncTombstones
        .filter()
        .deletedAtLessThan(cutoff)
        .findAll();
    await _isar.writeTxn(
      () => _isar.syncTombstones.deleteAll(old.map((t) => t.id).toList()),
    );
    return old.length;
  }

  // ---- Convenience wrappers used by the entity repositories -------------

  Future<void> tombstoneNote(Note n) => addTombstones('note', [n.syncId]);

  Future<void> tombstoneFolder(NoteFolder f) =>
      addTombstones('folder', [f.syncId]);

  Future<void> tombstoneTag(Tag t) => addTombstones('tag', [t.syncId]);

  Future<void> tombstoneAttachments(List<Attachment> list) =>
      addTombstones('attachment', [for (final a in list) a.syncId]);
}
