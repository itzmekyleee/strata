import 'dart:math';

/// RFC-4122-shaped v4 UUID from a secure random source.
String newUuid() {
  final rnd = Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0F) | 0x40;
  b[8] = (b[8] & 0x3F) | 0x80;
  String hex(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
      '${hex(4)}${hex(5)}-'
      '${hex(6)}${hex(7)}-'
      '${hex(8)}${hex(9)}-'
      '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
}

/// Deterministic last-write-wins decision. When timestamps tie, the greater
/// [tiebreakA] string wins so every peer converges on the same choice.
bool remoteWins({
  required int localUpdatedMs,
  required int remoteUpdatedMs,
  required String localTiebreak,
  required String remoteTiebreak,
}) {
  if (remoteUpdatedMs != localUpdatedMs) {
    return remoteUpdatedMs > localUpdatedMs;
  }
  return remoteTiebreak.compareTo(localTiebreak) > 0;
}
