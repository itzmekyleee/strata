import 'package:isar_community/isar.dart';

import '../../core/utils/data_bus.dart';
import '../../core/utils/ids.dart';
import '../models/note.dart';
import '../models/sync_tombstone.dart';
import '../models/tag.dart';

class TagsRepository {
  TagsRepository(this._isar);

  final Isar _isar;

  Future<List<Tag>> _allSorted() async {
    final list = await _isar.tags.filter().idGreaterThan(-1).findAll();
    return list..sort((a, b) => a.name.compareTo(b.name));
  }

  Stream<List<Tag>> watchAll() => watchLive(
        changes: [_isar.tags.watchLazy(), DataBus.stream],
        snapshot: _allSorted,
      );

  Future<Tag> create(String name, int colorValue) async {
    final tag = Tag()
      ..syncId = newUuid()
      ..name = name.trim()
      ..colorValue = colorValue
      ..updatedAt = DateTime.now();
    final id = await _isar.writeTxn(() => _isar.tags.put(tag));
    DataBus.ping();
    return (await _isar.tags.get(id))!;
  }

  Future<void> rename(Tag tag, String name, int colorValue) async {
    tag.name = name.trim();
    tag.colorValue = colorValue;
    tag.updatedAt = DateTime.now();
    await _isar.writeTxn(() => _isar.tags.put(tag));
    DataBus.ping();
  }

  Future<void> delete(Tag tag) async {
    await _isar.writeTxn(() async {
      final notes = await _isar.notes
          .filter()
          .tags((q) => q.idEqualTo(tag.id))
          .findAll();
      for (final n in notes) {
        n.tags.remove(tag);
        await n.tags.save();
      }
      if (tag.syncId.isNotEmpty) {
        final t = SyncTombstone()
          ..key = 'tag:${tag.syncId}'
          ..collection = 'tag'
          ..uuid = tag.syncId
          ..deletedAt = DateTime.now();
        await _isar.syncTombstones.put(t);
      }
      await _isar.tags.delete(tag.id);
    });
    DataBus.ping();
  }

  Future<void> setTagsForNote(Note note, List<Tag> selected) async {
    await _isar.writeTxn(() async {
      final fresh = await _isar.notes.get(note.id) ?? note;
      await fresh.tags.load();
      fresh.tags.clear();
      fresh.tags.addAll(selected);
      await fresh.tags.save();
      // Bump so membership changes propagate to sync peers.
      fresh.updatedAt = DateTime.now();
      if (fresh.syncId.isEmpty) fresh.syncId = newUuid();
      await _isar.notes.put(fresh);
    });
    DataBus.ping();
  }

  Future<List<Tag>> tagsForNote(Note note) async {
    await note.tags.load();
    return note.tags.toList()..sort((a, b) => a.name.compareTo(b.name));
  }
}
