import 'package:isar_community/isar.dart';

import 'tag.dart';

part 'note.g.dart';

@collection
class Note {
  Id id = Isar.autoIncrement;

  /// Globally unique identity used by LAN sync. Empty on legacy rows until
  /// backfilled at startup.
  @Index(unique: true, replace: true)
  String syncId = '';

  @Index(type: IndexType.value, caseSensitive: false)
  String title = '';

  String contentDelta = '';

  String plainPreview = '';

  @Index()
  int? folderId;

  final tags = IsarLinks<Tag>();

  @Index()
  bool isTrashed = false;

  DateTime? trashedAt;

  bool pinned = false;

  @Index()
  bool isTemplate = false;

  int wordCount = 0;

  int charCount = 0;

  @Index()
  DateTime updatedAt = DateTime.now();

  DateTime createdAt = DateTime.now();

  @Index()
  DateTime? dueDate;
}
