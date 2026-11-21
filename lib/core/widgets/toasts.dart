import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/strata_palette.dart';

enum ToastType { success, error, info }

class ToastMessage {
  const ToastMessage({
    required this.id,
    required this.type,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final int id;
  final ToastType type;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class ToastListNotifier extends Notifier<List<ToastMessage>> {
  int _nextId = 0;
  final Map<int, Timer> _timers = {};

  @override
  List<ToastMessage> build() => const [];

  void show(
    String text, {
    ToastType type = ToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 2600),
  }) {
    final toast = ToastMessage(
      id: _nextId++,
      type: type,
      text: text,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    var items = [...state, toast];
    if (items.length > 3) items = items.sublist(items.length - 3);
    state = items;
    // Toasts with actions stay visible longer so the user can tap them.
    final autoDismiss = onAction != null
        ? const Duration(seconds: 6)
        : duration;
    _timers[toast.id] = Timer(autoDismiss, () {
      dismiss(toast.id);
    });
  }

  void dismiss(int id) {
    _timers[id]?.cancel();
    _timers.remove(id);
    state = state.where((t) => t.id != id).toList();
  }
}

final toastProvider = NotifierProvider<ToastListNotifier, List<ToastMessage>>(
  ToastListNotifier.new,
);

void showToast(WidgetRef ref, String text, {ToastType type = ToastType.info}) {
  ref.read(toastProvider.notifier).show(text, type: type);
}

/// Shows an undo-style toast. [onUndo] is called if the user taps the action
/// button within the display window. [onExpire] fires after the window closes
/// without an undo — use this for deferred deletion.
void showUndoToast(
  WidgetRef ref,
  String text, {
  required VoidCallback onUndo,
  VoidCallback? onExpire,
}) {
  ref.read(toastProvider.notifier).show(
        text,
        type: ToastType.info,
        actionLabel: 'Undo',
        onAction: onUndo,
      );
  // After 6 seconds (the auto-dismiss window), fire the expire callback.
  if (onExpire != null) {
    Future<void>.delayed(const Duration(seconds: 6), onExpire);
  }
}

class ToastOverlayHost extends ConsumerWidget {
  const ToastOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(toastProvider);
    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final toast in toasts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _GlassToast(toast: toast)
                      .animate()
                      .slideY(
                        begin: -1.2,
                        end: 0,
                        duration: 320.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .fadeIn(duration: 220.ms),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassToast extends ConsumerWidget {
  const _GlassToast({required this.toast});

  final ToastMessage toast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (icon, tint) = switch (toast.type) {
      ToastType.success => (
        Icons.check_circle_rounded,
        StrataPalette.mint,
      ),
      ToastType.error => (Icons.error_rounded, StrataPalette.coral),
      ToastType.info => (Icons.info_rounded, StrataPalette.accent),
    };
    return Dismissible(
      key: ValueKey('toast-${toast.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => ref.read(toastProvider.notifier).dismiss(toast.id),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => ref.read(toastProvider.notifier).dismiss(toast.id),
          child: Ink(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: .92,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: StrataPalette.outlineStrong),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    tint.withValues(alpha: .16),
                    tint.withValues(alpha: .04),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: tint, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      toast.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (toast.actionLabel != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        toast.onAction?.call();
                        ref.read(toastProvider.notifier).dismiss(toast.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          toast.actionLabel!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: tint,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
