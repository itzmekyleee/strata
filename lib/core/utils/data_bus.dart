import 'dart:async';

/// Lightweight in-process change signal.
///
/// Every repository write pings the bus, and every watch stream merges it
/// alongside Isar's native query watchers. This guarantees that data always
/// (re)flows after local mutations even when native watcher delivery is
/// unavailable or unreliable — the initial emission of a watch stream comes
/// from a plain `findAll`, never from the watcher itself.
abstract final class DataBus {
  static final _ctrl = StreamController<void>.broadcast();

  static Stream<void> get stream => _ctrl.stream;

  static void ping() => _ctrl.add(null);
}

/// Merges multiple streams into a single broadcast-ish stream. Cancels all
/// sources when the merged stream is cancelled.
Stream<void> mergeChanges(Iterable<Stream<void>> streams) {
  final sources = streams.toList(growable: false);
  late StreamController<void> ctrl;
  final subs = <StreamSubscription<void>>[];

  ctrl = StreamController<void>(
    onListen: () {
      for (final s in sources) {
        subs.add(s.listen(ctrl.add, onError: ctrl.addError));
      }
    },
    onPause: () {
      for (final s in subs) {
        s.pause();
      }
    },
    onResume: () {
      for (final s in subs) {
        s.resume();
      }
    },
    onCancel: () => Future.wait(subs.map((s) => s.cancel())),
  );
  return ctrl.stream;
}

/// Canonical reactive read pattern:
///   yield snapshot immediately, then re-snapshot on every change.
Stream<S> watchLive<S>({
  required Iterable<Stream<void>> changes,
  required Future<S> Function() snapshot,
}) async* {
  yield await snapshot();
  yield* mergeChanges(changes).asyncMap((_) => snapshot());
}
