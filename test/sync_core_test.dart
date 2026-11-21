import 'package:flutter_test/flutter_test.dart';
import 'package:strata/core/utils/ids.dart';
import 'package:strata/data/services/sync/sync_payload.dart';

void main() {
  group('remoteWins (LWW)', () {
    test('newer remote timestamp wins', () {
      expect(
        remoteWins(
          localUpdatedMs: 100,
          remoteUpdatedMs: 200,
          localTiebreak: 'z',
          remoteTiebreak: 'a',
        ),
        isTrue,
      );
    });

    test('older remote loses even with greater tiebreak', () {
      expect(
        remoteWins(
          localUpdatedMs: 300,
          remoteUpdatedMs: 100,
          localTiebreak: 'a',
          remoteTiebreak: 'z',
        ),
        isFalse,
      );
    });

    test('tie breaks on device id, deterministically both ways', () {
      // Device 'b' wins over 'a' regardless of which side is local.
      final aAsLocal = remoteWins(
        localUpdatedMs: 100,
        remoteUpdatedMs: 100,
        localTiebreak: 'a',
        remoteTiebreak: 'b',
      );
      final aAsRemote = remoteWins(
        localUpdatedMs: 100,
        remoteUpdatedMs: 100,
        localTiebreak: 'b',
        remoteTiebreak: 'a',
      );
      expect(aAsLocal, isTrue);
      expect(aAsRemote, isFalse);
    });

    test('identical timestamps and ids never overwrite', () {
      expect(
        remoteWins(
          localUpdatedMs: 42,
          remoteUpdatedMs: 42,
          localTiebreak: 'same',
          remoteTiebreak: 'same',
        ),
        isFalse,
      );
    });
  });

  group('newUuid', () {
    test('produces v4-shaped unique ids', () {
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        final id = newUuid();
        expect(
          id,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        seen.add(id);
      }
      expect(seen.length, 500);
    });
  });

  group('SyncPayload', () {
    test('json round-trip preserves records and device', () {
      const device = SyncDevice(id: 'dev-1', name: 'Pixel');
      final payload = SyncPayload(
        device: device,
        folders: [
          {'u': 'f1', 'name': 'Work', 'parent': null},
        ],
        tags: [
          {'u': 't1', 'name': 'urgent', 'colorValue': 0xFF112233},
        ],
        notes: [
          {
            'u': 'n1',
            'title': 'Hello',
            'tags': ['t1'],
          },
        ],
        attachments: const [],
        tombstones: [
          {'c': 'note', 'u': 'nX', 'at': 12345},
        ],
      );

      final restored = SyncPayload.fromJson(
        (payload.toJson() as Map).cast<String, dynamic>(),
      );

      expect(restored.device.id, 'dev-1');
      expect(restored.device.name, 'Pixel');
      expect(restored.folders.single['name'], 'Work');
      expect(restored.tags.single['colorValue'], 0xFF112233);
      expect(restored.notes.single['title'], 'Hello');
      expect((restored.notes.single['tags'] as List).single, 't1');
      expect(restored.tombstones.single['u'], 'nX');
      expect(restored.totalRecords, 3);
    });

    test('tolerates missing sections', () {
      final p = SyncPayload.fromJson({
        'device': {'id': 'x'},
      });
      expect(p.folders, isEmpty);
      expect(p.tags, isEmpty);
      expect(p.notes, isEmpty);
      expect(p.attachments, isEmpty);
      expect(p.tombstones, isEmpty);
      expect(p.device.name, 'Unknown');
    });
  });
}
