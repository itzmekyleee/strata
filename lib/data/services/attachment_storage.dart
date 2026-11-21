import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredFile {
  const StoredFile({
    required this.relativePath,
    required this.sizeBytes,
    required this.mimeType,
  });

  final String relativePath;
  final int sizeBytes;
  final String mimeType;
}

class AttachmentStorage {
  late final Directory rootDir;

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    rootDir = Directory(p.join(docs.path, 'attachments'));
    if (!rootDir.existsSync()) rootDir.createSync(recursive: true);
  }

  File resolve(String relativePath) => File(p.join(rootDir.path, relativePath));

  Future<StoredFile> import(File source) async {
    final ext = p.extension(source.path);
    final name = '${DateTime.now().microsecondsSinceEpoch}_${_rand()}$ext';
    final target = resolve(name);
    await source.copy(target.path);
    return StoredFile(
      relativePath: name,
      sizeBytes: target.lengthSync(),
      mimeType: lookupMimeType(name) ?? 'application/octet-stream',
    );
  }

  Future<StoredFile> importBytes(List<int> bytes, String suggestedName) async {
    final ext = p.extension(suggestedName);
    final name = '${DateTime.now().microsecondsSinceEpoch}_${_rand()}$ext';
    final target = resolve(name);
    await target.writeAsBytes(bytes, flush: true);
    return StoredFile(
      relativePath: name,
      sizeBytes: bytes.length,
      mimeType: lookupMimeType(suggestedName) ?? 'application/octet-stream',
    );
  }

  Future<void> deleteRelative(String relativePath) async {
    final f = resolve(relativePath);
    if (f.existsSync()) await f.delete();
  }

  /// Resolves embed data (a stored relative name, absolute path, or file:// URI)
  /// to a local [File], or null for remote/data sources.
  File? resolveEmbedSource(String data) {
    if (data.startsWith('data:') || data.startsWith('http')) return null;
    final raw = data.startsWith('file://')
        ? Uri.parse(data).toFilePath()
        : data;
    if (raw.startsWith('/')) {
      final f = File(raw);
      return f.existsSync() ? f : null;
    }
    final f = resolve(raw);
    return f.existsSync() ? f : null;
  }

  static String _rand() =>
      (DateTime.now().microsecondsSinceEpoch % 99991).toRadixString(36);
}
