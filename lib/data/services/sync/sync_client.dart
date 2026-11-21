import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:isar_community/isar.dart';

import '../attachment_storage.dart';
import 'sync_apply.dart';
import 'sync_payload.dart';

class SyncExchangeResult {
  const SyncExchangeResult({
    required this.applied,
    required this.fetchedFiles,
    required this.peer,
  });

  final ApplyResult applied;
  final int fetchedFiles;
  final SyncDevice peer;
}

class PeerUnreachable implements Exception {
  const PeerUnreachable(this.host, this.port);

  final String host;
  final int port;

  @override
  String toString() => 'Peer unreachable at $host:$port';
}

/// Client side of the exchange: push our state, apply the peer's state,
/// then pull any attachment files we are missing.
Future<SyncExchangeResult> exchangeWith({
  required String host,
  required int port,
  required Isar isar,
  required AttachmentStorage storage,
  required SyncDevice localDevice,
}) async {
  // Reachability probe with a tight timeout.
  try {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
  } catch (_) {
    throw PeerUnreachable(host, port);
  }

  final mine = await buildPayload(isar: isar, device: localDevice, storage: storage);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client
        .postUrl(Uri.parse('http://$host:$port/sync'))
        .timeout(const Duration(seconds: 5));
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode(mine.toJson())));
    final resp = await req.close().timeout(const Duration(minutes: 2));
    if (resp.statusCode != 200) {
      throw 'Peer responded ${resp.statusCode}';
    }
    final body = await utf8.decoder.bind(resp).join();
    final decoded = jsonDecode(body) as Map<String, dynamic>;

    final theirs = SyncPayload.fromJson(
      (decoded['payload'] as Map).cast<String, dynamic>(),
    );
    final applied = await applyRemotePayload(
      isar: isar,
      storage: storage,
      payload: theirs,
      localTiebreak: localDevice.id,
      remoteTiebreak: theirs.device.id,
    );

    // Phase 2a: Fetch files we are missing from the peer.
    var fetched = 0;
    for (final path in applied.missingFiles) {
      try {
        final bytes = await _fetchAttachment(client, host, port, path);
        await storage.resolve(path).writeAsBytes(bytes, flush: true);
        fetched++;
      } catch (_) {
        // Leave the row in place; a later sync retries the fetch.
      }
    }

    // Phase 2b: Serve files the peer is missing (reverse fetch).
    final peerMissing = (decoded['missingFiles'] as List?)?.cast<String>() ?? const [];
    for (final path in peerMissing) {
      try {
        final f = storage.resolve(path);
        if (!f.existsSync()) continue;
        await _uploadAttachment(client, host, port, path, f);
      } catch (_) {}
    }

    return SyncExchangeResult(
      applied: applied,
      fetchedFiles: fetched,
      peer: theirs.device,
    );
  } finally {
    client.close(force: true);
  }
}

Future<List<int>> _fetchAttachment(
  HttpClient client,
  String host,
  int port,
  String path,
) async {
  final req = await client
      .getUrl(Uri.parse('http://$host:$port/att/${Uri.encodeComponent(path)}'))
      .timeout(const Duration(seconds: 5));
  final resp = await req.close().timeout(const Duration(minutes: 5));
  if (resp.statusCode != 200) {
    throw 'Attachment $path → HTTP ${resp.statusCode}';
  }
  return await resp.fold<List<int>>(<int>[], (acc, chunk) {
    acc.addAll(chunk);
    return acc;
  });
}

Future<void> _uploadAttachment(
  HttpClient client,
  String host,
  int port,
  String path,
  File file,
) async {
  final req = await client
      .putUrl(Uri.parse('http://$host:$port/att/${Uri.encodeComponent(path)}'))
      .timeout(const Duration(seconds: 5));
  req.headers.contentType = ContentType('application', 'octet-stream');
  await req.addStream(file.openRead());
  final resp = await req.close().timeout(const Duration(minutes: 5));
  if (resp.statusCode != 200) {
    throw 'Upload $path → HTTP ${resp.statusCode}';
  }
}
