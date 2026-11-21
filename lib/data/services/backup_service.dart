import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import '../database.dart';
import '../models/attachment.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/note_link.dart';
import '../models/tag.dart';
import 'attachment_storage.dart';

class BackupService {
  BackupService(this._db, this._storage);

  final AppDatabase _db;
  final AttachmentStorage _storage;

  static const int schemaVersion = 3;

  Future<File> exportToFile(String destinationPath) async {
    final isar = _db.isar;
    final folders = await isar.noteFolders.filter().idGreaterThan(-1).findAll();
    final tags = await isar.tags.filter().idGreaterThan(-1).findAll();
    final notes = await isar.notes.filter().idGreaterThan(-1).findAll();
    final attachments = await isar.attachments
        .filter()
        .idGreaterThan(-1)
        .findAll();
    final links = await isar.noteLinks
        .filter()
        .idGreaterThan(-1)
        .findAll();

    final meta = {
      'app': 'strata',
      'schema': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'folders': [
        for (final f in folders)
          {
            'id': f.id,
            'name': f.name,
            'parentId': f.parentId,
            'sortOrder': f.sortOrder,
            'colorValue': f.colorValue,
            'createdAt': f.createdAt.toIso8601String(),
            'updatedAt': f.updatedAt.toIso8601String(),
          },
      ],
      'tags': [
        for (final t in tags)
          {'id': t.id, 'name': t.name, 'colorValue': t.colorValue},
      ],
      'notes': [
        for (final n in notes)
          {
            'id': n.id,
            'title': n.title,
            'contentDelta': n.contentDelta,
            'plainPreview': n.plainPreview,
            'folderId': n.folderId,
            'tagIds': [for (final t in n.tags) t.id],
            'isTrashed': n.isTrashed,
            'trashedAt': n.trashedAt?.toIso8601String(),
            'pinned': n.pinned,
            'isTemplate': n.isTemplate,
            'dueDate': n.dueDate?.toIso8601String(),
            'wordCount': n.wordCount,
            'charCount': n.charCount,
            'createdAt': n.createdAt.toIso8601String(),
            'updatedAt': n.updatedAt.toIso8601String(),
          },
      ],
      'attachments': [
        for (final a in attachments)
          {
            'id': a.id,
            'noteId': a.noteId,
            'storedPath': a.storedPath,
            'fileName': a.fileName,
            'mimeType': a.mimeType,
            'sizeBytes': a.sizeBytes,
            'createdAt': a.createdAt.toIso8601String(),
          },
      ],
      'links': [
        for (final l in links)
          {'id': l.id, 'fromId': l.fromId, 'toId': l.toId},
      ],
    };

    final encoder = ZipEncoder();
    final archive = Archive();
    archive.addFile(ArchiveFile.string('meta.json', jsonEncode(meta)));

    final seen = <String>{};
    for (final a in attachments) {
      if (!seen.add(a.storedPath)) continue;
      final f = _storage.resolve(a.storedPath);
      if (f.existsSync()) {
        archive.addFile(
          ArchiveFile(
            'files/${p.basename(a.storedPath)}',
            f.lengthSync(),
            f.readAsBytesSync(),
          ),
        );
      }
    }
    for (final f in _storage.rootDir.listSync()) {
      if (f is! File) continue;
      final name = p.basename(f.path);
      if (seen.contains(name)) continue;
      archive.addFile(
        ArchiveFile('files/$name', f.lengthSync(), f.readAsBytesSync()),
      );
    }

    final out = File(destinationPath);
    await out.writeAsBytes(encoder.encode(archive));
    return out;
  }

  /// Replaces the entire database + attachment files with the backup's
  /// contents. Returns the number of imported notes.
  Future<int> restoreFromFile(String path) async {
    final bytes = File(path).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    final metaFile = archive.findFile('meta.json');
    if (metaFile == null) {
      throw const FormatException('Not a Strata backup file');
    }
    final meta =
        jsonDecode(utf8.decode(metaFile.content as List<int>))
            as Map<String, dynamic>;
    if (meta['app'] != 'strata') {
      throw const FormatException('Not a Strata backup file');
    }
    final version = (meta['schema'] as num?)?.toInt() ?? 0;
    if (version > schemaVersion) {
      throw const FormatException('Backup was created by a newer app version');
    }

    final isar = _db.isar;
    await isar.writeTxn(() async {
      await isar.notes.clear();
      await isar.noteFolders.clear();
      await isar.tags.clear();
      await isar.attachments.clear();
    });

    for (final f in _storage.rootDir.listSync()) {
      if (f is File) await f.delete();
    }
    for (final entry in archive) {
      if (entry.isFile && entry.name.startsWith('files/')) {
        final name = p.basename(entry.name);
        await File(
          p.join(_storage.rootDir.path, name),
        ).writeAsBytes(entry.content as List<int>);
      }
    }

    await isar.writeTxn(() async {
      for (final raw in (meta['folders'] as List).cast<Map>()) {
        final m = raw.cast<String, dynamic>();
        final folder = NoteFolder()
          ..id = (m['id'] as num).toInt()
          ..name = m['name'] as String? ?? ''
          ..parentId = (m['parentId'] as num?)?.toInt()
          ..sortOrder = (m['sortOrder'] as num?)?.toInt() ?? 0
          ..colorValue = (m['colorValue'] as num?)?.toInt() ?? 0xFF5B5BD6
          ..createdAt =
              DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now()
          ..updatedAt =
              DateTime.tryParse(m['updatedAt'] ?? '') ?? DateTime.now();
        await isar.noteFolders.put(folder);
      }

      for (final raw in (meta['tags'] as List).cast<Map>()) {
        final m = raw.cast<String, dynamic>();
        final tag = Tag()
          ..id = (m['id'] as num).toInt()
          ..name = m['name'] as String? ?? ''
          ..colorValue = (m['colorValue'] as num?)?.toInt() ?? 0xFF5B5BD6;
        await isar.tags.put(tag);
      }

      for (final raw in (meta['notes'] as List).cast<Map>()) {
        final m = raw.cast<String, dynamic>();
        final note = Note()
          ..id = (m['id'] as num).toInt()
          ..title = m['title'] as String? ?? ''
          ..contentDelta = m['contentDelta'] as String? ?? ''
          ..plainPreview = m['plainPreview'] as String? ?? ''
          ..folderId = (m['folderId'] as num?)?.toInt()
          ..isTrashed = m['isTrashed'] as bool? ?? false
          ..trashedAt = DateTime.tryParse(m['trashedAt'] ?? '')
          ..pinned = m['pinned'] as bool? ?? false
          ..isTemplate = m['isTemplate'] as bool? ?? false
          ..dueDate = DateTime.tryParse(m['dueDate'] ?? '')
          ..wordCount = (m['wordCount'] as num?)?.toInt() ?? 0
          ..charCount = (m['charCount'] as num?)?.toInt() ?? 0
          ..createdAt =
              DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now()
          ..updatedAt =
              DateTime.tryParse(m['updatedAt'] ?? '') ?? DateTime.now();
        final id = await isar.notes.put(note);
        final tagIds = ((m['tagIds'] as List?) ?? const []).map(
          (e) => (e as num).toInt(),
        );
        final storedNote = await isar.notes.get(id);
        if (storedNote != null && tagIds.isNotEmpty) {
          await storedNote.tags.load();
          storedNote.tags.addAll(
            (await isar.tags.getAll(tagIds.toList())).whereType<Tag>(),
          );
          await storedNote.tags.save();
        }
      }

      for (final raw in (meta['attachments'] as List).cast<Map>()) {
        final m = raw.cast<String, dynamic>();
        final att = Attachment()
          ..id = (m['id'] as num).toInt()
          ..noteId = (m['noteId'] as num?)?.toInt() ?? 0
          ..storedPath = m['storedPath'] as String? ?? ''
          ..fileName = m['fileName'] as String? ?? ''
          ..mimeType = m['mimeType'] as String? ?? ''
          ..sizeBytes = (m['sizeBytes'] as num?)?.toInt() ?? 0
          ..createdAt =
              DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now();
        await isar.attachments.put(att);
      }

      for (final raw in (meta['links'] as List? ?? const []).cast<Map>()) {
        final m = raw.cast<String, dynamic>();
        await isar.noteLinks.put(NoteLink()
          ..id = (m['id'] as num).toInt()
          ..fromId = (m['fromId'] as num?)?.toInt() ?? 0
          ..toId = (m['toId'] as num?)?.toInt() ?? 0);
      }
    });

    return (meta['notes'] as List).length;
  }
}
