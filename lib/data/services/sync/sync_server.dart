import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import '../attachment_storage.dart';
import 'sync_apply.dart';
import 'sync_payload.dart';

/// Serves the sync protocol over LAN HTTP:
///
/// - `GET  /ping`        → device identity
/// - `POST /sync`        → exchange full-state payloads (LWW applied here)
/// - `GET  /att/<name>`  → attachment bytes (basename only)
class SyncServer {
  SyncServer({
    required this.isar,
    required this.storage,
    required this.device,
    required this.localTiebreak,
  });

  final Isar isar;
  final AttachmentStorage storage;
  final SyncDevice Function() device;
  final String localTiebreak;

  HttpServer? _server;
  bool _busy = false;

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    unawaited(_serve());
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;
    await for (final req in server) {
      unawaited(_handle(req));
    }
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final path = req.uri.path;
      if (req.method == 'GET' && path == '/ping') {
        return await _json(req, 200, device().toJson());
      }
      if (req.method == 'POST' && path == '/sync') {
        return await _sync(req);
      }
      if (req.method == 'GET' && path.startsWith('/att/')) {
        return await _attachment(req);
      }
      if (req.method == 'PUT' && path.startsWith('/att/')) {
        return await _uploadAttachment(req);
      }
      await _json(req, 404, {'error': 'not found'});
    } catch (_) {
      try {
        await _json(req, 500, {'error': 'internal'});
      } catch (_) {}
    }
  }

  Future<void> _sync(HttpRequest req) async {
    if (_busy) {
      return await _json(req, 503, {'error': 'sync in progress'});
    }
    _busy = true;
    try {
      final body = await utf8.decoder.bind(req).join();
      final payload = SyncPayload.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
      final result = await applyRemotePayload(
        isar: isar,
        storage: storage,
        payload: payload,
        localTiebreak: localTiebreak,
        remoteTiebreak: payload.device.id,
      );
      // Respond with our own state so the peer applies the same merge.
      final mine = await buildPayload(isar: isar, device: device(), storage: storage);
      await _json(req, 200, {
        'result': {
          'notesApplied': result.notesApplied,
          'notesDeleted': result.notesDeleted,
        },
        'payload': mine.toJson(),
        'missingFiles': result.missingFiles,
      });
    } finally {
      _busy = false;
    }
  }

  /// Accepts uploaded attachment bytes from the peer (reverse fetch).
  Future<void> _uploadAttachment(HttpRequest req) async {
    final name = p.basename(req.uri.path.substring('/att/'.length));
    if (name.isEmpty || name == '.' || name == '..') {
      return await _json(req, 400, {'error': 'invalid name'});
    }
    final target = storage.resolve(name);
    // Ensure parent directory exists.
    final parent = target.parent;
    if (!parent.existsSync()) parent.createSync(recursive: true);
    final sink = target.openWrite();
    await sink.addStream(req);
    await _json(req, 200, {'ok': true});
  }

  Future<void> _attachment(HttpRequest req) async {
    final name = p.basename(req.uri.path.substring('/att/'.length));
    final f = storage.resolve(name);
    if (!f.existsSync()) {
      return await _json(req, 404, {'error': 'missing'});
    }
    req.response.headers.contentType = ContentType(
      'application',
      'octet-stream',
    );
    await f.openRead().pipe(req.response);
  }

  Future<void> _json(HttpRequest req, int status, Object body) async {
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }
}
