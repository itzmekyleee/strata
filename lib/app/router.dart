import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/attachments/attachment_viewer_screen.dart';
import '../features/editor/editor_screen.dart';
import '../features/home/home_screen.dart';
import '../features/planned/planned_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/tags/tags_screen.dart';
import '../features/trash/trash_screen.dart';

class AttachmentViewArgs {
  const AttachmentViewArgs({required this.path, required this.name});

  final String path;
  final String name;
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/notes',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notes',
                pageBuilder: (context, state) =>
                    _fade(state, const HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/planned',
                pageBuilder: (context, state) =>
                    _fade(state, const PlannedScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trash',
                pageBuilder: (context, state) =>
                    _fade(state, const TrashScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) =>
                    _fade(state, const SettingsScreen()),
                routes: [
                  GoRoute(
                    path: 'tags',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        _slide(state, const TagsScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/editor/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return CustomTransitionPage(
            key: state.pageKey,
            child: EditorScreen(noteId: id),
            transitionDuration: const Duration(milliseconds: 280),
            transitionsBuilder: (context, animation, secondary, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return SlideTransition(
                position: Tween(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: FadeTransition(
                  opacity: curved,
                  child: child,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/viewer',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final args = state.extra as AttachmentViewArgs;
          return _slideRaw(state, AttachmentViewerScreen(args: args));
        },
      ),
    ],
  );
});

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );

CustomTransitionPage<void> _slide(GoRouterState state, Widget child) =>
    _slideRaw(state, child);

CustomTransitionPage<void> _slideRaw(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
