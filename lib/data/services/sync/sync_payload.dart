import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../../../core/utils/ids.dart';
import '../../models/attachment.dart';
import '../../models/note.dart';
import '../../models/note_folder.dart';
import '../../models/tag.dart';
import '../../repositories/sync_repository.dart';
import '../attachment_storage.dart';

/// Device identity carried inside every exchange.
class SyncDevice {
  const SyncDevice({required this.id, required this.name});

  factory SyncDevice.fromJson(Map<String, dynamic> j) => SyncDevice(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Unknown',
  );

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Full-state snapshot exchanged between peers. Records reference each
/// other by [syncId] (`u`) instead of local autoincrement ids.
class SyncPayload {
  const SyncPayload({
    required this.device,
    required this.folders,
    required this.tags,
    required this.notes,
    required this.attachments,
    required this.tombstones,
  });

  factory SyncPayload.fromJson(Map<String, dynamic> j) => SyncPayload(
    device: SyncDevice.fromJson((j['device'] as Map).cast<String, dynamic>()),
    folders: _records(j['folders']),
    tags: _records(j['tags']),
    notes: _records(j['notes']),
    attachments: _records(j['attachments']),
    tombstones: _records(j['tombstones']),
  );

  static List<Map<String, dynamic>> _records(Object? raw) =>
      ((raw as List?) ?? const [])
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();

  final SyncDevice device;
  final List<Map<String, dynamic>> folders;
  final List<Map<String, dynamic>> tags;
  final List<Map<String, dynamic>> notes;
  final List<Map<String, dynamic>> attachments;
  final List<Map<String, dynamic>> tombstones;

  Map<String, dynamic> toJson() => {
    'app': 'strata-sync',
    'schema': 1,
    'device': device.toJson(),
    'folders': folders,
    'tags': tags,
    'notes': notes,
    'attachments': attachments,
    'tombstones': tombstones,
  };

  int get totalRecords =>
      folders.length + tags.length + notes.length + attachments.length;
}

int _ms(DateTime? dt) => (dt ?? DateTime.now()).millisecondsSinceEpoch;

/// Builds the outgoing full-state snapshot for this device.
///
/// Also scans note deltas for image embed references and auto-creates
/// attachment records for any files that exist on disk but are missing
/// from the database (legacy images inserted before Attachment tracking).
Future<SyncPayload> buildPayload({
  required Isar isar,
  required SyncDevice device,
  required AttachmentStorage storage,
}) async {
  final folders = await isar.noteFolders.where().findAll();
  final tags = await isar.tags.where().findAll();
  final notes = await isar.notes.where().findAll();
  final attachments = await isar.attachments.where().findAll();
  final tombs = await SyncRepository(isar).allTombstones();

  // Scan note deltas for image embed references and auto-create
  // Attachment records for any orphaned files on disk.
  final existingPaths = <String>{for (final a in attachments) a.storedPath};
  for (final n in notes) {
    if (n.contentDelta.isEmpty) continue;
    final refs = _imageRefsFromDelta(n.contentDelta);
    for (final ref in refs) {
      if (existingPaths.contains(ref)) continue;
      final f = storage.resolve(ref);
      if (!f.existsSync()) continue;
      final att = Attachment()
        ..syncId = newUuid()
        ..noteId = n.id
        ..storedPath = ref
        ..fileName = ref
        ..mimeType = 'application/octet-stream'
        ..sizeBytes = f.lengthSync()
        ..createdAt = DateTime.now();
      await isar.writeTxn(() => isar.attachments.put(att));
      attachments.add(att);
      existingPaths.add(ref);
    }
  }

  return SyncPayload(
    device: device,
    folders: [
      for (final f in folders)
        {
          'u': f.syncId,
          'name': f.name,
          'parent': f.parentId == null ? null : _uuidOf(folders, f.parentId!),
          'sortOrder': f.sortOrder,
          'colorValue': f.colorValue,
          'createdAt': _ms(f.createdAt),
          'updatedAt': _ms(f.updatedAt),
        },
    ],
    tags: [
      for (final t in tags)
        {
          'u': t.syncId,
          'name': t.name,
          'colorValue': t.colorValue,
          'updatedAt': _ms(t.updatedAt),
        },
    ],
    notes: [
      for (final n in notes)
        {
          'u': n.syncId,
          'title': n.title,
          'delta': n.contentDelta,
          'preview': n.plainPreview,
          'folder': n.folderId == null ? null : _uuidOf(folders, n.folderId!),
          'tags': [for (final t in n.tags) t.syncId],
          'trashed': n.isTrashed,
          'trashedAt': n.trashedAt?.millisecondsSinceEpoch,
          'pinned': n.pinned,
          'template': n.isTemplate,
          'dueDate': n.dueDate?.millisecondsSinceEpoch,
          'wc': n.wordCount,
          'cc': n.charCount,
          'createdAt': _ms(n.createdAt),
          'updatedAt': _ms(n.updatedAt),
        },
    ],
    attachments: [
      for (final a in attachments)
        {
          'u': a.syncId,
          'note': _noteUuidOf(notes, a.noteId),
          'path': a.storedPath,
          'fileName': a.fileName,
          'mimeType': a.mimeType,
          'sizeBytes': a.sizeBytes,
          'createdAt': _ms(a.createdAt),
        },
    ],
    tombstones: [
      for (final t in tombs)
        {'c': t.collection, 'u': t.uuid, 'at': _ms(t.deletedAt)},
    ],
  );
}

/// Extracts image embed references (stored file names) from a quill delta JSON string.
List<String> _imageRefsFromDelta(String deltaJson) {
  final refs = <String>[];
  try {
    final ops = jsonDecode(deltaJson) as List;
    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert is! Map) continue;
      final image = insert['image'];
      if (image is! String || image.isEmpty) continue;
      if (image.startsWith('data:') || image.startsWith('http')) continue;
      final raw = image.startsWith('file://')
          ? Uri.parse(image).toFilePath()
          : image;
      final name = raw.startsWith('/') ? _basename(raw) : raw;
      if (name.isNotEmpty) refs.add(name);
    }
  } catch (_) {}
  return refs;
}

String _basename(String path) {
  final lastSlash = path.lastIndexOf('/');
  return lastSlash < 0 ? path : path.substring(lastSlash + 1);
}

String? _uuidOf(List<NoteFolder> folders, int localId) {
  for (final f in folders) {
    if (f.id == localId) return f.syncId.isEmpty ? null : f.syncId;
  }
  return null;
}

String? _noteUuidOf(List<Note> notes, int localId) {
  for (final n in notes) {
    if (n.id == localId) return n.syncId.isEmpty ? null : n.syncId;
  }
  return null;
}
