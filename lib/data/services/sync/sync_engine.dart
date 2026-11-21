import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

import '../../../core/utils/ids.dart';
import '../attachment_storage.dart';
import 'sync_apply.dart';
import 'sync_client.dart';
import 'sync_payload.dart';
import 'sync_server.dart';

const String kSyncServiceType = '_strata-sync._tcp';

class SyncConfig {
  SyncConfig({
    required this.deviceId,
    this.deviceName = 'Strata device',
    this.enabled = false,
    this.autoSync = false,
  });

  factory SyncConfig.fromJson(Map<String, dynamic> j) => SyncConfig(
    deviceId: j['deviceId'] as String,
    deviceName: j['deviceName'] as String? ?? 'Strata device',
    enabled: j['enabled'] as bool? ?? false,
    autoSync: j['autoSync'] as bool? ?? false,
  );

  final String deviceId;
  final String deviceName;
  final bool enabled;
  final bool autoSync;

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'enabled': enabled,
    'autoSync': autoSync,
  };

  SyncConfig copyWith({String? deviceName, bool? enabled, bool? autoSync}) =>
      SyncConfig(
        deviceId: deviceId,
        deviceName: deviceName ?? this.deviceName,
        enabled: enabled ?? this.enabled,
        autoSync: autoSync ?? this.autoSync,
      );
}

class PeerInfo {
  const PeerInfo({
    required this.deviceId,
    required this.name,
    required this.host,
    required this.port,
    this.lastSyncAt,
    this.busy = false,
  });

  final String deviceId;
  final String name;
  final String host;
  final int port;

  /// Epoch ms of our last successful exchange with this peer, if known.
  final int? lastSyncAt;
  final bool busy;

  PeerInfo copyWith({
    String? name,
    String? host,
    int? port,
    int? lastSyncAt,
    bool? busy,
  }) => PeerInfo(
    deviceId: deviceId,
    name: name ?? this.name,
    host: host ?? this.host,
    port: port ?? this.port,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    busy: busy ?? this.busy,
  );
}

class SyncOutcome {
  const SyncOutcome(this.ok, this.detail);
  final bool ok;
  final String detail;
}

/// Owns the LAN-sync lifecycle: identity/config, HTTP server, mDNS
/// advertisement + discovery, manual/auto exchanges.
class SyncEngine extends ChangeNotifier {
  SyncEngine({required this.isar, required this.storage});

  final Isar isar;
  final AttachmentStorage storage;

  static const _autoSyncInterval = Duration(minutes: 5);

  SyncConfig _config = SyncConfig(deviceId: '');
  SyncServer? _server;
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription? _discoverySub;
  Timer? _timer;
  bool _starting = false;

  /// Called after each successful exchange so hosts can re-arm reminders
  /// for remotely-changed notes.
  Future<void> Function(ApplyResult result)? onExchangeApplied;

  final Map<String, PeerInfo> _peers = {};

  SyncConfig get config => _config;
  List<PeerInfo> get peers =>
      _peers.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  bool get running => _server?.isRunning == true;

  File get _configFile =>
      File('${storage.rootDir.parent.path}/strata_sync.json');

  Future<void> load() async {
    try {
      if (_configFile.existsSync()) {
        _config = SyncConfig.fromJson(
          jsonDecode(_configFile.readAsStringSync()) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    if (_config.deviceId.isEmpty) {
      _config = SyncConfig(
        deviceId: newUuid(),
        deviceName: defaultDeviceName(),
      );
      await _save();
    }
    notifyListeners();
  }

  String defaultDeviceName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'Strata device';
    }
  }

  Future<void> _save() async {
    try {
      await _configFile.writeAsString(
        jsonEncode(_config.toJson()),
        flush: true,
      );
    } catch (_) {}
  }

  // ---- Lifecycle ----------------------------------------------------------

  Future<void> start() async {
    if (!config.enabled || running || _starting) return;
    _starting = true;
    try {
      final server = SyncServer(
        isar: isar,
        storage: storage,
        device: () =>
            SyncDevice(id: _config.deviceId, name: _config.deviceName),
        localTiebreak: _config.deviceId,
      );
      await server.start();
      _server = server;

      final service = BonsoirService(
        name: _config.deviceName,
        type: kSyncServiceType,
        port: server.port,
        attributes: {'sid': _config.deviceId},
      );
      final broadcast = BonsoirBroadcast(service: service);
      await broadcast.initialize();
      await broadcast.start();
      _broadcast = broadcast;

      final discovery = BonsoirDiscovery(type: kSyncServiceType);
      await discovery.initialize();
      _discoverySub = discovery.eventStream?.listen(_onDiscoveryEvent);
      await discovery.start();
      _discovery = discovery;

      if (_config.autoSync) _startTimer();
    } catch (e) {
      debugPrint('SyncEngine start failed: $e');
      await stop(keepConfig: true);
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> stop({bool keepConfig = false}) async {
    _timer?.cancel();
    _timer = null;
    await _discoverySub?.cancel();
    _discoverySub = null;
    try {
      await _discovery?.stop();
    } catch (_) {}
    _discovery = null;
    try {
      await _broadcast?.stop();
    } catch (_) {}
    _broadcast = null;
    await _server?.stop();
    _server = null;
    if (!keepConfig) notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoSyncInterval, (_) {
      unawaited(() async {
        try {
          await syncAll();
        } catch (_) {}
      }());
    });
  }

  void _onDiscoveryEvent(BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent(:final service):
        // Resolve explicitly when the platform only reports "found".
        _discovery?.serviceResolver.resolveService(service);
      case BonsoirDiscoveryServiceResolvedEvent(:final service):
        _upsertPeer(service);
      case BonsoirDiscoveryServiceLostEvent(:final service):
        final sid = service.attributes['sid'];
        if (sid != null) {
          _peers.remove(sid);
          notifyListeners();
        }
      default:
        break;
    }
  }

  void _upsertPeer(BonsoirService service) {
    final sid = service.attributes['sid'];
    if (sid == null || sid == _config.deviceId) return;
    final host = service.hostAddresses.isNotEmpty
        ? service.hostAddresses.first
        : (service.hostname
                  ?.replaceAll('.local.', '')
                  .replaceAll('.local', '') ??
              '');
    if (host.isEmpty) return;
    final existing = _peers[sid];
    _peers[sid] =
        (existing ??
                PeerInfo(
                  deviceId: sid,
                  name: service.name,
                  host: host,
                  port: service.port,
                ))
            .copyWith(name: service.name, host: host, port: service.port);
    notifyListeners();
  }

  // ---- Configuration ------------------------------------------------------

  Future<void> setEnabled(bool value) async {
    _config = _config.copyWith(enabled: value);
    await _save();
    if (value) {
      await start();
    } else {
      await stop(keepConfig: true);
      notifyListeners();
    }
  }

  Future<void> setAutoSync(bool value) async {
    _config = _config.copyWith(autoSync: value);
    await _save();
    if (value && running) {
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
    notifyListeners();
  }

  Future<void> setDeviceName(String value) async {
    final name = value.trim();
    if (name.isEmpty) return;
    _config = _config.copyWith(deviceName: name);
    await _save();
    // Re-advertise under the new name.
    if (running) {
      await stop(keepConfig: true);
      await start();
    }
    notifyListeners();
  }

  // ---- Exchanges ----------------------------------------------------------
  Future<SyncOutcome> syncWith(PeerInfo peer) async {
    _peers[peer.deviceId] = peer.copyWith(busy: true);
    notifyListeners();
    try {
      final result = await exchangeWith(
        host: peer.host,
        port: peer.port,
        isar: isar,
        storage: storage,
        localDevice: SyncDevice(id: _config.deviceId, name: _config.deviceName),
      );
      await onExchangeApplied?.call(result.applied);
      _peers[peer.deviceId] = peer.copyWith(
        busy: false,
        lastSyncAt: DateTime.now().millisecondsSinceEpoch,
      );
      return SyncOutcome(true, result.toString());
    } catch (e) {
      _peers[peer.deviceId] = peer.copyWith(busy: false);
      return SyncOutcome(false, '$e');
    } finally {
      notifyListeners();
    }
  }

  Future<int> syncAll() async {
    var ok = 0;
    for (final p in peers) {
      final outcome = await syncWith(p);
      if (outcome.ok) ok++;
    }
    return ok;
  }
}
