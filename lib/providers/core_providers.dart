import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repositories/attachments_repository.dart';
import '../data/repositories/folders_repository.dart';
import '../data/repositories/notes_repository.dart';
import '../data/repositories/tags_repository.dart';
import '../data/services/attachment_storage.dart';
import '../data/services/backup_service.dart';
import '../data/services/delta_to_docx.dart';
import '../data/services/delta_to_pdf.dart';
import '../data/services/note_actions.dart';
import '../data/services/reminder_service.dart';
import '../data/repositories/sync_repository.dart';
import '../data/services/sync/sync_engine.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

final storageProvider = Provider<AttachmentStorage>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

final notesRepositoryProvider = Provider(
  (ref) => NotesRepository(ref.watch(databaseProvider).isar),
);

final foldersRepositoryProvider = Provider(
  (ref) => FoldersRepository(ref.watch(databaseProvider).isar),
);

final tagsRepositoryProvider = Provider(
  (ref) => TagsRepository(ref.watch(databaseProvider).isar),
);

final attachmentsRepositoryProvider = Provider(
  (ref) => AttachmentsRepository(
    ref.watch(databaseProvider).isar,
    ref.watch(storageProvider),
  ),
);

final remindersProvider = Provider<ReminderService>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

final noteActionsProvider = Provider(
  (ref) => NoteActions(
    ref.watch(notesRepositoryProvider),
    ref.watch(attachmentsRepositoryProvider),
    ref.watch(storageProvider),
    ref.watch(remindersProvider),
  ),
);

final backupServiceProvider = Provider(
  (ref) =>
      BackupService(ref.watch(databaseProvider), ref.watch(storageProvider)),
);

final pdfConverterProvider = Provider(
  (ref) => DeltaToPdfConverter(ref.watch(storageProvider)),
);

final docxConverterProvider = Provider(
  (ref) => DeltaToDocxConverter(ref.watch(storageProvider)),
);

final syncRepositoryProvider = Provider(
  (ref) => SyncRepository(ref.watch(databaseProvider).isar),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

/// Holds image paths shared to Strata from other apps while the editor
/// is not open. The home screen watches this and auto-creates a note.
class PendingSharedImages extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void add(List<String> paths) => state = [...state, ...paths];

  List<String> takeAll() {
    final copy = [...state];
    state = const [];
    return copy;
  }
}

final pendingSharedImagesProvider =
    NotifierProvider<PendingSharedImages, List<String>>(
  PendingSharedImages.new,
);
