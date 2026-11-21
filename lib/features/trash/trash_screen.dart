import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/strata_palette.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/skeleton_card.dart';
import '../../core/widgets/toasts.dart';
import '../../providers/core_providers.dart';
import '../../providers/notes_providers.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashAsync = ref.watch(trashStreamProvider);
    final dateFmt = DateFormat.MMMEd().add_jm();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Trash'),
        actions: [
          IconButton(
            tooltip: 'Empty trash',
            onPressed: () => _confirmEmptyTrash(context, ref),
            icon: const Icon(Icons.delete_forever_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: trashAsync.when(
          loading: () => const NoteListSkeleton(count: 4),
          error: (e, _) => Center(child: Text('$e')),
          data: (notes) {
            if (notes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 52,
                      color: StrataPalette.onSurfaceMuted.withValues(alpha: .35),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Trash is empty',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Deleted notes rest here for 30 days.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: StrataPalette.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: notes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final note = notes[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: StrataPalette.outline,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Text(
                          note.title.trim().isEmpty
                              ? 'Untitled'
                              : note.title.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Deleted ${note.trashedAt != null ? dateFmt.format(note.trashedAt!.toLocal()) : 'recently'} · ${note.wordCount} words',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: StrataPalette.onSurfaceMuted,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Restore',
                              icon: const Icon(
                                Icons.restore_rounded,
                                color: StrataPalette.mint,
                              ),
                              onPressed: () async {
                                await ref
                                    .read(noteActionsProvider)
                                    .restore(note.id);
                                showToast(ref, 'Note restored');
                              },
                            ),
                            IconButton(
                              tooltip: 'Delete forever',
                              icon: Icon(
                                Icons.delete_forever_rounded,
                                color: StrataPalette.coral.withValues(alpha: .9),
                              ),
                              onPressed: () =>
                                  _confirmDeleteForever(context, ref, note.id),
                            ),
                          ],
                        ),
                      ),
                    ).entrance(index: i);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeleteForever(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete forever?',
      message: 'This permanently removes the note and its files. This cannot '
          'be undone.',
      confirmLabel: 'Delete forever',
      icon: Icons.delete_forever_rounded,
    );
    if (confirmed == true) {
      await ref.read(noteActionsProvider).deleteForever(id);
      showToast(ref, 'Deleted forever');
    }
  }

  Future<void> _confirmEmptyTrash(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Empty trash?',
      message: 'All trashed notes will be gone forever. This cannot be undone.',
      confirmLabel: 'Empty trash',
      icon: Icons.delete_sweep_rounded,
    );
    if (confirmed != true) return;
    final notes = await ref.read(trashStreamProvider.future);
    for (final n in notes) {
      await ref.read(noteActionsProvider).deleteForever(n.id);
    }
    if (context.mounted) showToast(ref, 'Trash emptied');
  }
}
