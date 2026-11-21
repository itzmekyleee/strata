import 'package:isar_community/isar.dart';

part 'note_link.g.dart';

/// A directed reference between two notes, created when a note's content
/// contains a resolved [[wiki link]] to another note's title.
@collection
class NoteLink {
  Id id = Isar.autoIncrement;

  @Index()
  int fromId = 0;

  @Index()
  int toId = 0;
}
