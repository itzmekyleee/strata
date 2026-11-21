import 'package:isar_community/isar.dart';

part 'tag.g.dart';

@collection
class Tag {
  Id id = Isar.autoIncrement;

  /// Globally unique identity used by LAN sync.
  @Index(unique: true, replace: true)
  String syncId = '';

  @Index(unique: true, replace: true)
  String name = '';

  int colorValue = 0xFF5B5BD6;

  DateTime updatedAt = DateTime.now();
}
