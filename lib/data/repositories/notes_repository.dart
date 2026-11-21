import 'package:isar_community/isar.dart';

import '../../core/utils/data_bus.dart';
import '../../providers/notes_providers.dart';
import '../models/note.dart';
import '../models/note_link.dart';
import '../models/sync_tombstone.dart';
import 'package:strata/core/utils/ids.dart';
import 'package:strata/core/utils/text_stats.dart';

class NotesRepository {
  NotesRepository(this._isar);

  final Isar _isar;

  /// Change signals for the notes collection (native watchers + local bus).
  Iterable<Stream<void>> get _changes => [
        _isar.notes.watchLazy(),
        DataBus.stream,
      ];

  Stream<List<Note>> watchNotes({
    int? folderId,
    NoteSort sort = NoteSort.updated,
  }) {
    Future<List<Note>> snapshot() async {
      final base = _isar.notes
          .filter()
          .isTrashedEqualTo(false)
          .isTemplateEqualTo(false);
      // A null folder id means root-level (unfiled) notes.
      final q = folderId == null
          ? base.folderIdIsNull()
          : base.folderIdEqualTo(folderId);
      switch (sort) {
        case NoteSort.updated:
          return q.sortByUpdatedAtDesc().findAll();
        case NoteSort.dueDate:
          // Due-dated notes first (soonest at top); the rest keep recency order.
          final all = await q.findAll();
          final withDue = all.where((n) => n.dueDate != null).toList()
            ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
          final rest = all.where((n) => n.dueDate == null).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return [...withDue, ...rest];
        case NoteSort.titleAsc:
          final all = await q.findAll();
          all.sort((a, b) => a.title
              .toLowerCase()
              .compareTo(b.title.toLowerCase()));
          return all;
      }
    }

    return watchLive(changes: _changes, snapshot: snapshot);
  }

  /// All non-trashed, non-template notes across every folder.
  Stream<List<Note>> watchAll() {
    Future<List<Note>> snapshot() async {
      return _isar.notes
          .filter()
          .isTrashedEqualTo(false)
          .isTemplateEqualTo(false)
          .sortByUpdatedAtDesc()
          .findAll();
    }

    return watchLive(changes: _changes, snapshot: snapshot);
  }

  /// Non-trashed, non-template notes whose reminder is still in the future.
  Future<List<Note>> upcomingReminders(DateTime now) => _isar.notes
      .filter()
      .isTrashedEqualTo(false)
      .isTemplateEqualTo(false)
      .dueDateIsNotNull()
      .dueDateGreaterThan(now)
      .findAll();

  Stream<List<Note>> watchPinned({int? folderId}) {
    Future<List<Note>> snapshot() async {
      var q = _isar.notes
          .filter()
          .isTrashedEqualTo(false)
          .isTemplateEqualTo(false)
          .pinnedEqualTo(true);
      if (folderId != null) {
        q = q.folderIdEqualTo(folderId);
      }
      return q.sortByUpdatedAtDesc().findAll();
    }

    return watchLive(changes: _changes, snapshot: snapshot);
  }

  Stream<List<Note>> watchTemplates() {
    Future<List<Note>> snapshot() async {
      final list =
          await _isar.notes.filter().isTemplateEqualTo(true).findAll();
      return list
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    return watchLive(changes: _changes, snapshot: snapshot);
  }

  Stream<List<Note>> watchTrash() {
    Future<List<Note>> snapshot() => _isar.notes
        .filter()
        .isTrashedEqualTo(true)
        .sortByTrashedAtDesc()
        .findAll();

    return watchLive(changes: _changes, snapshot: snapshot);
  }

  Stream<Note?> watchById(int id) =>
      _isar.notes.watchObject(id, fireImmediately: true);

  Future<Note?> getById(int id) => _isar.notes.get(id);

  Future<int> save(Note note) async {
    note.updatedAt = DateTime.now();
    if (note.syncId.isEmpty) note.syncId = newUuid();
    final id = await _isar.writeTxn(() => _isar.notes.put(note));
    DataBus.ping();
    return id;
  }

  Future<void> moveToTrash(int id) async {
    await _isar.writeTxn(() async {
      final n = await _isar.notes.get(id);
      if (n == null) return;
      n.isTrashed = true;
      n.trashedAt = DateTime.now();
      await _isar.notes.put(n);
    });
    DataBus.ping();
  }

  Future<void> restore(int id) async {
    await _isar.writeTxn(() async {
      final n = await _isar.notes.get(id);
      if (n == null) return;
      n.isTrashed = false;
      n.trashedAt = null;
      await _isar.notes.put(n);
    });
    DataBus.ping();
  }

  Future<void> deleteForever(int id) async {
    await _isar.writeTxn(() async {
      final n = await _isar.notes.get(id);
      if (n == null) return;
      if (n.syncId.isNotEmpty) {
        final t = SyncTombstone()
          ..key = 'note:${n.syncId}'
          ..collection = 'note'
          ..uuid = n.syncId
          ..deletedAt = DateTime.now();
        await _isar.syncTombstones.put(t);
      }
      await _isar.notes.delete(id);
    });
    DataBus.ping();
  }

  // ---- Wiki links -------------------------------------------------------

  /// Best match for an exact (case-insensitive) note title, ignoring
  /// trashed notes and templates. Most recently updated wins on collision.
  Future<Note?> findByTitle(String title) async {
    final t = title.trim();
    if (t.isEmpty) return null;
    final hits = await _isar.notes
        .filter()
        .isTrashedEqualTo(false)
        .isTemplateEqualTo(false)
        .titleEqualTo(t, caseSensitive: false)
        .sortByUpdatedAtDesc()
        .findAll();
    return hits.isEmpty ? null : hits.first;
  }

  /// Title-prefix matches for the [[ autocomplete popup.
  Future<List<Note>> findSuggestions(
    String prefix, {
    required int excludeNoteId,
    int limit = 8,
  }) async {
    final base = _isar.notes
        .filter()
        .isTrashedEqualTo(false)
        .isTemplateEqualTo(false);
    final q = prefix.trim().isEmpty
        ? base.sortByUpdatedAtDesc()
        : base
              .titleStartsWith(prefix.trim(), caseSensitive: false)
              .sortByUpdatedAtDesc();
    final hits = await q.findAll();
    return hits.where((n) => n.id != excludeNoteId).take(limit).toList();
  }

  /// Replaces all outbound links of [noteId] based on the `[[titles]]`
  /// found in its plain text. Unresolvable titles are skipped; they can be
  /// re-linked later when a matching note exists and the source is saved.
  Future<void> rebuildLinks({
    required int noteId,
    required List<String> titles,
  }) async {
    final resolved = <int>{};
    for (final raw in titles) {
      final target = await findByTitle(raw);
      final id = target?.id;
      if (id == null || id == noteId) continue;
      resolved.add(id);
    }
    await _isar.writeTxn(() async {
      final existing = await _isar.noteLinks
          .filter()
          .fromIdEqualTo(noteId)
          .findAll();
      final existingIds = existing.map((l) => l.toId).toSet();
      for (final row in existing) {
        if (!resolved.contains(row.toId)) {
          await _isar.noteLinks.delete(row.id);
        }
      }
      for (final toId in resolved.where((id) => !existingIds.contains(id))) {
        await _isar.noteLinks.put(
          NoteLink()
            ..fromId = noteId
            ..toId = toId,
        );
      }
    });
    DataBus.ping();
  }

  /// Notes that contain a link pointing at [noteId].
  Stream<List<Note>> watchBacklinks(int noteId) {
    Future<List<Note>> snapshot() async {
      final rows = await _isar.noteLinks
          .filter()
          .toIdEqualTo(noteId)
          .findAll();
      if (rows.isEmpty) return const <Note>[];
      final sources = await _isar.notes.getAll(
        rows.map((r) => r.fromId).toSet().toList(),
      );
      return sources
          .whereType<Note>()
          .where((n) => !n.isTrashed && !n.isTemplate)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    return watchLive(changes: _changes, snapshot: snapshot);
  }

  /// Removes every link row touching [noteId] (in or out).
  Future<void> deleteAllLinksOf(int noteId) {
    return _isar.writeTxn(() async {
      await _isar.noteLinks.filter().fromIdEqualTo(noteId).deleteAll();
      await _isar.noteLinks.filter().toIdEqualTo(noteId).deleteAll();
    });
  }

  /// All links (used by backup export).
  Future<List<NoteLink>> allLinks() =>
      _isar.noteLinks.filter().idGreaterThan(-1).findAll();

  Future<List<Note>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final t = query.trim().toLowerCase();
    final byTitle = await _isar.notes
        .filter()
        .isTrashedEqualTo(false)
        .isTemplateEqualTo(false)
        .titleContains(t, caseSensitive: false)
        .findAll();
    final byBody = await _isar.notes
        .filter()
        .isTrashedEqualTo(false)
        .isTemplateEqualTo(false)
        .plainPreviewContains(t, caseSensitive: false)
        .findAll();
    final map = <int, Note>{for (final n in byTitle) n.id: n};
    for (final n in byBody) {
      map.putIfAbsent(n.id, () => n);
    }
    return map.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<List<Note>> trashedOlderThan(DateTime cutoff) => _isar.notes
      .filter()
      .isTrashedEqualTo(true)
      .trashedAtLessThan(cutoff)
      .findAll();

  Future<List<Note>> all() => _isar.notes.where().findAll();

  static void applyStats(Note note) {
    final plain = TextStats.plainFromDelta(note.contentDelta);
    note.wordCount = TextStats.wordCount(plain);
    note.charCount = plain.length;
    note.plainPreview = plain.trim().isEmpty
        ? ''
        : plain.substring(0, plain.length.clamp(0, 400));
  }
}
