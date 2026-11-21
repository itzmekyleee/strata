import 'package:isar_community/isar.dart';

part 'sync_tombstone.g.dart';

/// Records a hard deletion so LAN-sync peers remove their copies too.
/// Keyed by `<collection>:<uuid>` so repeated deletes collapse.
@collection
class SyncTombstone {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String key = '';

  /// 'note' | 'folder' | 'tag' | 'attachment'
  String collection = '';

  String uuid = '';

  DateTime deletedAt = DateTime.now();
}
