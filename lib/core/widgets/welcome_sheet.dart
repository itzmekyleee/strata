import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/strata_palette.dart';

const _kFirstRunKey = 'strata_first_run_done';

/// Returns `true` if this is the first time the app has launched.
Future<bool> isFirstRun() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kFirstRunKey) ?? false);
}

/// Marks the first-run as complete.
Future<void> completeFirstRun() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kFirstRunKey, true);
}

/// Shows a one-time welcome sheet on first launch.
/// Returns after the user taps "Get started".
Future<void> showWelcomeSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WelcomeSheet(),
  );
}

class _WelcomeSheet extends ConsumerWidget {
  const _WelcomeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: StrataPalette.outline),
      ),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [StrataPalette.accent, StrataPalette.amber],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: StrataPalette.accent.withValues(alpha: .25),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'S',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome to Strata',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A fast, offline-first note-taking app with rich editing, '
            'folders, tags, and local LAN sync.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: StrataPalette.onSurfaceMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _TipRow(
            icon: Icons.folder_outlined,
            text: 'Organize notes with folders and tags',
          ),
          const SizedBox(height: 8),
          _TipRow(
            icon: Icons.edit_note_rounded,
            text: 'Rich editor with tables, images, and wiki links',
          ),
          const SizedBox(height: 8),
          _TipRow(
            icon: Icons.sync_rounded,
            text: 'Sync across devices over your local network',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: StrataPalette.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                await completeFirstRun();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text(
                'Get started',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: StrataPalette.accent.withValues(alpha: .8)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: StrataPalette.onSurfaceMuted,
                  height: 1.3,
                ),
          ),
        ),
      ],
    );
  }
}
