import '../models/note.dart';
import 'attachment_storage.dart';
import 'reminder_service.dart';
import '../repositories/attachments_repository.dart';
import '../repositories/notes_repository.dart';
import '../../core/utils/text_stats.dart' show TextStats;
import '../../core/utils/wiki_links.dart' show WikiLinks;

class NoteActions {
  NoteActions(this._notes, this._attachments, this._storage, this._reminders);

  final NotesRepository _notes;
  final AttachmentsRepository _attachments;
  final AttachmentStorage _storage;
  final ReminderService _reminders;

  Future<Note> createNote({
    int? folderId,
    String title = '',
    String contentDelta = '',
  }) async {
    final note = Note()
      ..title = title
      ..folderId = folderId
      ..contentDelta = contentDelta
      ..createdAt = DateTime.now();
    NotesRepository.applyStats(note);
    final id = await _notes.save(note);
    return (await _notes.getById(id))!;
  }

  /// Duplicates [src] as a reusable template; returns the new template id.
  Future<int> saveAsTemplate(Note src) async {
    final template = Note()
      ..title = src.title.trim().isEmpty ? 'Untitled template' : src.title
      ..contentDelta = src.contentDelta
      ..isTemplate = true
      ..createdAt = DateTime.now();
    NotesRepository.applyStats(template);
    return _notes.save(template);
  }

  Future<void> saveContent(Note note, String deltaJson, {String? title}) {
    note.contentDelta = deltaJson;
    if (title != null) note.title = title.trim();
    NotesRepository.applyStats(note);
    final links = _notes.rebuildLinks(
      noteId: note.id,
      titles: WikiLinks.extractTitles(TextStats.plainFromDelta(deltaJson)),
    );
    return Future.wait([_notes.save(note), links]);
  }

  Future<void> trash(int id) async {
    await _notes.moveToTrash(id);
    await _reminders.cancel(id);
  }

  Future<void> restore(int id) async {
    await _notes.restore(id);
    final n = await _notes.getById(id);
    if (n != null) {
      await _reminders.scheduleFor(n);
    }
  }

  Future<void> deleteForever(int id) async {
    await _reminders.cancel(id);
    await _notes.deleteAllLinksOf(id);
    await _attachments.deleteAllOfNote(id);
    await _notes.deleteForever(id);
  }

  /// Removes notes whose trash date is older than [cutoff]; returns count.
  Future<int> purgeOlderThan(DateTime cutoff) async {
    final old = await _notes.trashedOlderThan(cutoff);
    for (final n in old) {
      await deleteForever(n.id);
    }
    return old.length;
  }

  Future<String?> previewFile(String relativePath) async {
    final f = _storage.resolveEmbedSource(relativePath);
    return f?.path;
  }
}
