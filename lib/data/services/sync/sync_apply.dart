import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/data_bus.dart';
import '../../../core/utils/ids.dart';
import '../../../core/utils/text_stats.dart';
import '../../../core/utils/wiki_links.dart';
import '../../models/attachment.dart';
import '../../models/note.dart';
import '../../models/note_link.dart';
import '../../models/note_folder.dart';
import '../../models/sync_tombstone.dart';
import '../../models/tag.dart';
import '../../repositories/notes_repository.dart';
import '../../repositories/sync_repository.dart';
import '../attachment_storage.dart';
import 'sync_payload.dart';

int _ms(DateTime? dt) => (dt ?? DateTime.now()).millisecondsSinceEpoch;

class ApplyResult {
  int foldersApplied = 0;
  int tagsApplied = 0;
  int notesApplied = 0;
  int notesDeleted = 0;
  int attachmentsApplied = 0;

  /// Local ids of notes removed or moved-to-trash by this merge — their
  /// reminders must be cancelled.
  final List<int> cancelledNoteIds = [];

  /// Attachment storedPaths whose bytes must be fetched from the peer.
  final List<String> missingFiles = [];

  bool get changed =>
      foldersApplied > 0 ||
      tagsApplied > 0 ||
      notesApplied > 0 ||
      notesDeleted > 0 ||
      attachmentsApplied > 0;

  @override
  String toString() =>
      '$notesApplied notes updated, $notesDeleted removed, '
      '$foldersApplied folders, $tagsApplied tags, '
      '${missingFiles.length} files pending';
}

/// Applies a peer's payload locally using last-write-wins semantics.
///
/// [localTiebreak] / [remoteTiebreak] are device ids used only when
/// timestamps tie, so both sides converge deterministically.
Future<ApplyResult> applyRemotePayload({
  required Isar isar,
  required AttachmentStorage storage,
  required SyncPayload payload,
  required String localTiebreak,
  required String remoteTiebreak,
}) async {
  final res = ApplyResult();
  final syncRepo = SyncRepository(isar);
  final notesRepo = NotesRepository(isar);
  final remote = payload.device.id;

  // ---- Folders (two passes so parents can arrive after children) --------
  final folderByUuid = <String, NoteFolder>{};
  for (final f in await isar.noteFolders.where().findAll()) {
    if (f.syncId.isNotEmpty) folderByUuid[f.syncId] = f;
  }
  final remoteFolders = payload.folders
      .where((r) => (r['u'] as String?)?.isNotEmpty == true)
      .toList();

  Future<void> upsertFolder(Map<String, dynamic> r) async {
    final u = r['u'] as String;
    final parentUuid = r['parent'] as String?;
    final existing = folderByUuid[u];
    if (existing != null &&
        !remoteWins(
          localUpdatedMs: _ms(existing.updatedAt),
          remoteUpdatedMs: r['updatedAt'] as int? ?? 0,
          localTiebreak: localTiebreak,
          remoteTiebreak: remote,
        )) {
      return;
    }
    final f = existing ?? (NoteFolder()..syncId = u);
    f.name = r['name'] as String? ?? f.name;
    f.sortOrder = (r['sortOrder'] as num?)?.toInt() ?? f.sortOrder;
    f.colorValue = (r['colorValue'] as num?)?.toInt() ?? f.colorValue;
    f.createdAt = DateTime.fromMillisecondsSinceEpoch(
      r['createdAt'] as int? ?? _ms(f.createdAt),
    );
    f.updatedAt = DateTime.fromMillisecondsSinceEpoch(
      r['updatedAt'] as int? ?? _ms(f.updatedAt),
    );
    f.parentId = parentUuid == null ? null : folderByUuid[parentUuid]?.id;
    await isar.writeTxn(() => isar.noteFolders.put(f));
    folderByUuid[f.syncId] = f;
    res.foldersApplied++;
  }

  for (final r in remoteFolders.where((r) => r['parent'] == null)) {
    await upsertFolder(r);
  }
  for (final r in remoteFolders.where((r) => r['parent'] != null)) {
    await upsertFolder(r);
  }

  // ---- Tags --------------------------------------------------------------
  final tagByUuid = <String, Tag>{};
  final tagByName = <String, Tag>{};
  for (final t in await isar.tags.where().findAll()) {
    if (t.syncId.isNotEmpty) tagByUuid[t.syncId] = t;
    tagByName[t.name.toLowerCase()] = t;
  }

  for (final r in payload.tags) {
    final u = r['u'] as String?;
    if (u == null || u.isEmpty) continue;
    var existing = tagByUuid[u];
    // Same-name tag created independently on both devices: adopt the
    // remote identity instead of duplicating it.
    existing ??= tagByName[(r['name'] as String? ?? '').toLowerCase()];
    if (existing != null &&
        !remoteWins(
          localUpdatedMs: _ms(existing.updatedAt),
          remoteUpdatedMs: r['updatedAt'] as int? ?? 0,
          localTiebreak: localTiebreak,
          remoteTiebreak: remote,
        )) {
      continue;
    }
    final t = existing ?? (Tag()..syncId = u);
    t.syncId = u;
    t.name = r['name'] as String? ?? t.name;
    t.colorValue = (r['colorValue'] as num?)?.toInt() ?? t.colorValue;
    t.updatedAt = DateTime.fromMillisecondsSinceEpoch(
      r['updatedAt'] as int? ?? _ms(t.updatedAt),
    );
    await isar.writeTxn(() => isar.tags.put(t));
    tagByUuid[u] = t;
    tagByName[t.name.toLowerCase()] = t;
    res.tagsApplied++;
  }

  // ---- Notes -------------------------------------------------------------
  final noteByUuid = <String, Note>{};
  for (final n in await isar.notes.where().findAll()) {
    if (n.syncId.isNotEmpty) noteByUuid[n.syncId] = n;
  }

  Future<void> rebuildLinks(Note n) => notesRepo.rebuildLinks(
    noteId: n.id,
    titles: WikiLinks.extractTitles(_plainFromDelta(n.contentDelta)),
  );

  Future<void> applyTagsTo(Note n, List<String> tagUuids) async {
    await n.tags.load();
    n.tags.clear();
    n.tags.addAll([
      for (final tu in tagUuids)
        if (tagByUuid[tu] != null) tagByUuid[tu]!,
    ]);
    await n.tags.save();
  }

  for (final r in payload.notes) {
    final u = r['u'] as String?;
    if (u == null || u.isEmpty) continue;
    final rUpdated = r['updatedAt'] as int? ?? 0;
    final existing = noteByUuid[u];

    if (existing != null) {
      if (!remoteWins(
        localUpdatedMs: _ms(existing.updatedAt),
        remoteUpdatedMs: rUpdated,
        localTiebreak: localTiebreak,
        remoteTiebreak: remote,
      )) {
        continue;
      }
      final deltaChanged =
          existing.contentDelta != (r['delta'] as String? ?? '');
      _fillNote(existing, r);
      final folderUuid = r['folder'] as String?;
      existing.folderId = folderUuid == null
          ? null
          : folderByUuid[folderUuid]?.id;
      await isar.writeTxn(() async {
        await isar.notes.put(existing);
        await applyTagsTo(existing, _tagUuids(r));
      });
      if (deltaChanged) await rebuildLinks(existing);
      noteByUuid[u] = existing;
      res.notesApplied++;
      if (existing.isTrashed) {
        res.cancelledNoteIds.add(existing.id);
      }
      continue;
    }

    final tomb = await isar.syncTombstones
        .filter()
        .keyEqualTo('note:$u')
        .findFirst();
    if (tomb != null && tomb.deletedAt.millisecondsSinceEpoch >= rUpdated) {
      continue; // deleted more recently than the incoming edit
    }

    final folderUuid = r['folder'] as String?;
    final n = Note()..syncId = u;
    _fillNote(n, r);
    n.folderId = folderUuid == null ? null : folderByUuid[folderUuid]?.id;
    await isar.writeTxn(() async {
      final id = await isar.notes.put(n);
      final fresh = await isar.notes.get(id);
      if (fresh == null) return;
      fresh.tags.addAll([
        for (final tu in _tagUuids(r))
          if (tagByUuid[tu] != null) tagByUuid[tu]!,
      ]);
      await fresh.tags.save();
      noteByUuid[u] = fresh;
    });
    await rebuildLinks(n);
    res.notesApplied++;
  }

  // ---- Attachments metadata ----------------------------------------------
  final attByUuid = <String, Attachment>{};
  for (final a in await isar.attachments.where().findAll()) {
    if (a.syncId.isNotEmpty) attByUuid[a.syncId] = a;
  }
  for (final r in payload.attachments) {
    final u = r['u'] as String?;
    final path = r['path'] as String?;
    if (u == null || path == null || !_safeRelative(path)) continue;
    final noteUuid = r['note'] as String?;
    final localNoteId = noteUuid == null ? null : noteByUuid[noteUuid]?.id;
    final existing = attByUuid[u];
    if (existing != null) {
      if (localNoteId != null && existing.noteId != localNoteId) {
        existing.noteId = localNoteId;
        await isar.writeTxn(() => isar.attachments.put(existing));
      }
      continue;
    }
    if (localNoteId == null) continue;
    final safeName = p.basename(path);
    final a = Attachment()
      ..syncId = u
      ..noteId = localNoteId
      ..storedPath = safeName
      ..fileName = r['fileName'] as String? ?? safeName
      ..mimeType = r['mimeType'] as String? ?? ''
      ..sizeBytes = (r['sizeBytes'] as num?)?.toInt() ?? 0
      ..createdAt = DateTime.fromMillisecondsSinceEpoch(
        r['createdAt'] as int? ?? 0,
      );
    await isar.writeTxn(() => isar.attachments.put(a));
    attByUuid[u] = a;
    res.attachmentsApplied++;
    if (!storage.resolve(a.storedPath).existsSync()) {
      res.missingFiles.add(a.storedPath);
    }
  }

  // ---- Tombstones: union + enforce ---------------------------------------
  for (final r in payload.tombstones) {
    final c = r['c'] as String?;
    final u = r['u'] as String?;
    if (c == null || u == null || u.isEmpty) continue;
    final at = r['at'] as int? ?? 0;
    final key = '$c:$u';
    final existing = await isar.syncTombstones
        .filter()
        .keyEqualTo(key)
        .findFirst();
    if (existing == null || existing.deletedAt.millisecondsSinceEpoch < at) {
      await isar.writeTxn(
        () => isar.syncTombstones.put(
          SyncTombstone()
            ..key = key
            ..collection = c
            ..uuid = u
            ..deletedAt = DateTime.fromMillisecondsSinceEpoch(at),
        ),
      );
    }
  }

  for (final t in await syncRepo.allTombstones()) {
    final at = t.deletedAt.millisecondsSinceEpoch;
    switch (t.collection) {
      case 'note':
        final n = noteByUuid[t.uuid];
        if (n == null || _ms(n.updatedAt) > at) break;
        final atts = await isar.attachments
            .filter()
            .noteIdEqualTo(n.id)
            .findAll();
        for (final a in atts) {
          await storage.deleteRelative(a.storedPath);
        }
        await isar.writeTxn(() async {
          await isar.noteLinks.filter().fromIdEqualTo(n.id).deleteAll();
          await isar.noteLinks.filter().toIdEqualTo(n.id).deleteAll();
          await isar.attachments.filter().noteIdEqualTo(n.id).deleteAll();
          await isar.notes.delete(n.id);
        });
        noteByUuid.remove(t.uuid);
        res.cancelledNoteIds.add(n.id);
        res.notesDeleted++;
      case 'folder':
        final f = folderByUuid[t.uuid];
        if (f == null || _ms(f.updatedAt) > at) break;
        await isar.writeTxn(() => isar.noteFolders.delete(f.id));
        folderByUuid.remove(t.uuid);
      case 'tag':
        final g = tagByUuid[t.uuid];
        if (g == null || _ms(g.updatedAt) > at) break;
        await isar.writeTxn(() => isar.tags.delete(g.id));
        tagByUuid.remove(t.uuid);
      case 'attachment':
        final a = attByUuid[t.uuid];
        if (a == null) break;
        await storage.deleteRelative(a.storedPath);
        await isar.writeTxn(() => isar.attachments.delete(a.id));
        attByUuid.remove(t.uuid);
    }
  }

  // Remote data landed directly via Isar writes; nudge every watcher.
  DataBus.ping();
  return res;
}

List<String> _tagUuids(Map<String, dynamic> r) =>
    ((r['tags'] as List?) ?? const []).cast<String>();

void _fillNote(Note n, Map<String, dynamic> r) {
  n.title = r['title'] as String? ?? n.title;
  n.contentDelta = r['delta'] as String? ?? n.contentDelta;
  n.plainPreview = r['preview'] as String? ?? n.plainPreview;
  n.isTrashed = r['trashed'] as bool? ?? n.isTrashed;
  final trashedAt = r['trashedAt'] as int?;
  n.trashedAt = trashedAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(trashedAt);
  n.pinned = r['pinned'] as bool? ?? n.pinned;
  n.isTemplate = r['template'] as bool? ?? n.isTemplate;
  final due = r['dueDate'] as int?;
  n.dueDate = due == null ? null : DateTime.fromMillisecondsSinceEpoch(due);
  n.wordCount = (r['wc'] as num?)?.toInt() ?? n.wordCount;
  n.charCount = (r['cc'] as num?)?.toInt() ?? n.charCount;
  n.createdAt = DateTime.fromMillisecondsSinceEpoch(
    r['createdAt'] as int? ?? _ms(n.createdAt),
  );
  n.updatedAt = DateTime.fromMillisecondsSinceEpoch(
    r['updatedAt'] as int? ?? _ms(n.updatedAt),
  );
}

bool _safeRelative(String path) =>
    !path.contains('/') &&
    !path.contains('\\') &&
    !path.startsWith('..') &&
    path != '.' &&
    path.isNotEmpty;

String _plainFromDelta(String deltaJson) {
  try {
    return TextStats.plainFromDelta(deltaJson);
  } catch (_) {
    return '';
  }
}
