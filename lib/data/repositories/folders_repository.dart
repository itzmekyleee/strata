import 'package:isar_community/isar.dart';

import '../../core/utils/data_bus.dart';
import '../../core/utils/ids.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/sync_tombstone.dart';

class FoldersRepository {
  FoldersRepository(this._isar);

  final Isar _isar;

  Stream<List<NoteFolder>> watchAll() => watchLive(
        changes: [_isar.noteFolders.watchLazy(), DataBus.stream],
        snapshot: allSorted,
      );

  Future<List<NoteFolder>> allSorted() async {
    final list = await _isar.noteFolders.filter().idGreaterThan(-1).findAll();
    return list..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<NoteFolder>> children(int? parentId) async {
    final list = parentId == null
        ? await _isar.noteFolders.filter().parentIdIsNull().findAll()
        : await _isar.noteFolders.filter().parentIdEqualTo(parentId).findAll();
    return list..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<NoteFolder> create(String name, int? parentId, int colorValue) async {
    final folder = NoteFolder()
      ..syncId = newUuid()
      ..name = name.trim()
      ..parentId = parentId
      ..colorValue = colorValue;
    final id = await _isar.writeTxn(() => _isar.noteFolders.put(folder));
    DataBus.ping();
    return (await _isar.noteFolders.get(id))!;
  }

  Future<void> rename(NoteFolder folder, String name) async {
    folder.name = name.trim();
    folder.updatedAt = DateTime.now();
    await _isar.writeTxn(() => _isar.noteFolders.put(folder));
    DataBus.ping();
  }

  /// Deletes [folder]; its subfolders and notes move up one level to the
  /// deleted folder's parent so nothing is lost.
  Future<void> deletePromotingChildren(int folderId) async {
    await _isar.writeTxn(() async {
      final folder = await _isar.noteFolders.get(folderId);
      if (folder == null) return;
      final subs = await _isar.noteFolders
          .filter()
          .parentIdEqualTo(folderId)
          .findAll();
      for (final s in subs) {
        s.parentId = folder.parentId;
        s.updatedAt = DateTime.now();
        await _isar.noteFolders.put(s);
      }
      final notes = await _isar.notes
          .filter()
          .folderIdEqualTo(folderId)
          .findAll();
      for (final n in notes) {
        n.folderId = folder.parentId;
        n.updatedAt = DateTime.now();
        await _isar.notes.put(n);
      }
      if (folder.syncId.isNotEmpty) {
        final t = SyncTombstone()
          ..key = 'folder:${folder.syncId}'
          ..collection = 'folder'
          ..uuid = folder.syncId
          ..deletedAt = DateTime.now();
        await _isar.syncTombstones.put(t);
      }
      await _isar.noteFolders.delete(folderId);
    });
    DataBus.ping();
  }

  Future<List<NoteFolder>> all() => _isar.noteFolders.where().findAll();
}
