import 'package:isar_community/isar.dart';

part 'note_folder.g.dart';

@collection
class NoteFolder {
  Id id = Isar.autoIncrement;

  /// Globally unique identity used by LAN sync.
  @Index(unique: true, replace: true)
  String syncId = '';

  @Index(type: IndexType.value, caseSensitive: false)
  String name = '';

  @Index()
  int? parentId;

  int sortOrder = 0;

  int colorValue = 0xFF5B5BD6;

  DateTime createdAt = DateTime.now();

  DateTime updatedAt = DateTime.now();
}
