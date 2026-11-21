import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GlobalShortcuts extends ConsumerWidget {
  const GlobalShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Ctrl/Cmd + N → New note
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyN,
        ): () => context.push('/editor/new'),
        if (isMac)
          LogicalKeySet(
            LogicalKeyboardKey.meta,
            LogicalKeyboardKey.keyN,
          ): () => context.push('/editor/new'),

        // Ctrl/Cmd + F → Toggle search (home screen watches this provider)
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyF,
        ): () => ref.read(searchToggleProvider.notifier).toggle(),
        if (isMac)
          LogicalKeySet(
            LogicalKeyboardKey.meta,
            LogicalKeyboardKey.keyF,
          ): () => ref.read(searchToggleProvider.notifier).toggle(),

        // Escape → Pop dialogs/sheets
        LogicalKeySet(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}

/// Toggled by keyboard shortcut; the HomeScreen watches this to show/hide search.
class SearchToggle extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final searchToggleProvider = NotifierProvider<SearchToggle, bool>(
  SearchToggle.new,
);
