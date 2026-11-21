import 'package:flutter/widgets.dart';

/// Tracks how many pointers (fingers/styluses) are currently touching the
/// app.
///
/// Quill only clears its selection-drag offset from gesture-end callbacks, so
/// a cancelled gesture (notification shade, incoming call, app switch) can
/// leave it dangling — which keeps the magnifier and the selection state
/// stuck. Knowing that no pointer is down anymore lets the editor detect and
/// clear that state safely.
class PointerActivity {
  PointerActivity._();

  static int _down = 0;

  /// Pointers currently touching the app.
  static int get activePointers => _down;

  /// Called on every pointer event seen by the root [Listener].
  static void handle(PointerEvent event) {
    if (event is PointerDownEvent) {
      _down++;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _release();
    }
  }

  /// Pointer events are not guaranteed to arrive in pairs (the system can
  /// steal them without notifying the app), so the count is clamped and can
  /// be reset wholesale via [reset].
  static void _release() {
    if (_down > 0) _down--;
  }

  /// Forgets all pointers; safe to call when the app is paused or resumed.
  static void reset() => _down = 0;

  /// Wraps the app so every pointer event inside it is counted.
  static Widget track({required Widget child}) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: handle,
    onPointerUp: handle,
    onPointerCancel: handle,
    child: child,
  );
}
