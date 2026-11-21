import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/attachment.dart';
import 'models/note.dart';
import 'models/note_folder.dart';
import 'models/note_link.dart';
import 'models/sync_tombstone.dart';
import 'models/tag.dart';

class AppDatabase {
  final Isar isar;

  AppDatabase(this.isar);

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [
        NoteSchema,
        NoteFolderSchema,
        TagSchema,
        AttachmentSchema,
        NoteLinkSchema,
        SyncTombstoneSchema,
      ],
      directory: dir.path,
      name: 'strata',
      inspector: false,
    );
    return AppDatabase(isar);
  }

  void close() => isar.close();
}
