import 'package:isar_community/isar.dart';

part 'attachment.g.dart';

@collection
class Attachment {
  Id id = Isar.autoIncrement;

  /// Globally unique identity used by LAN sync.
  @Index(unique: true, replace: true)
  String syncId = '';

  @Index()
  int noteId = 0;

  String storedPath = '';

  String fileName = '';

  String mimeType = '';

  int sizeBytes = 0;

  DateTime createdAt = DateTime.now();
}
