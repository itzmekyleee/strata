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

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  void _enterSelection(int id) => setState(() {
    _selectionMode = true;
    _selectedIds
      ..clear()
      ..add(id);
  });

  void _toggleSelection(int id) => setState(() {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      if (_selectedIds.isEmpty) _selectionMode = false;
    } else {
      _selectedIds.add(id);
    }
  });

  void _clearSelection() => setState(() {
    _selectionMode = false;
    _selectedIds.clear();
  });

  Future<void> _bulkRestore() async {
    final actions = ref.read(noteActionsProvider);
    final count = _selectedIds.length;
    for (final id in _selectedIds.toList()) {
      await actions.restore(id);
    }
    if (mounted) {
      showToast(ref, '$count note${count == 1 ? '' : 's'} restored');
      _clearSelection();
    }
  }

  Future<void> _bulkDeleteForever() async {
    final count = _selectedIds.length;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete $count note${count == 1 ? '' : 's'} forever?',
      message:
          'This permanently removes the selected notes and their files. This cannot be undone.',
      confirmLabel: 'Delete forever',
      icon: Icons.delete_forever_rounded,
    );
    if (confirmed != true) return;
    final actions = ref.read(noteActionsProvider);
    for (final id in _selectedIds.toList()) {
      await actions.deleteForever(id);
    }
    if (mounted) {
      showToast(ref, '$count note${count == 1 ? '' : 's'} deleted forever');
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trashAsync = ref.watch(trashStreamProvider);
    final dateFmt = DateFormat.MMMEd().add_jm();
    final size = MediaQuery.sizeOf(context);
    final isThreePane = size.width >= 1100 && size.width > size.height;

    final body = trashAsync.when(
      loading: () => const NoteListSkeleton(),
      error: (e, _) => Center(
        child: Text('Something went wrong\n$e', textAlign: TextAlign.center),
      ),
      data: (notes) {
        if (notes.isEmpty) {
          if (_selectionMode) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectionMode) _clearSelection();
            });
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_sweep_outlined,
                  size: 46,
                  color: StrataPalette.onSurfaceMuted.withValues(alpha: .7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Trash is empty',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Deleted notes stay here for 30 days.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: StrataPalette.onSurfaceMuted,
                  ),
                ),
              ],
            ).entrance(index: 0),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isThreePane ? double.infinity : 860,
            ),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
              itemCount: notes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final note = notes[i];
                final checked = _selectedIds.contains(note.id);
                return Container(
                  decoration: BoxDecoration(
                    color: checked
                        ? StrataPalette.accent.withValues(alpha: .08)
                        : Theme.of(context).colorScheme.surfaceContainerHighest
                              .withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: checked
                          ? StrataPalette.accent.withValues(alpha: .35)
                          : StrataPalette.outline,
                    ),
                  ),
                  child: ListTile(
                    onTap: _selectionMode
                        ? () => _toggleSelection(note.id)
                        : null,
                    onLongPress: _selectionMode
                        ? () => _toggleSelection(note.id)
                        : () => _enterSelection(note.id),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: _selectionMode
                        ? AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: checked
                                  ? StrataPalette.accent
                                  : Colors.transparent,
                              border: Border.all(
                                color: checked
                                    ? StrataPalette.accent
                                    : StrataPalette.onSurfaceMuted.withValues(
                                        alpha: .5,
                                      ),
                                width: 1.8,
                              ),
                            ),
                            child: checked
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          )
                        : null,
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
                    trailing: _selectionMode
                        ? null
                        : Row(
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
                                  color: StrataPalette.coral.withValues(
                                    alpha: .9,
                                  ),
                                ),
                                onPressed: () => _confirmDeleteForever(
                                  context,
                                  ref,
                                  note.id,
                                ),
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
    );

    final selectionActions = [
      IconButton(
        tooltip: 'Restore',
        onPressed: _selectedIds.isEmpty ? null : _bulkRestore,
        icon: const Icon(Icons.restore_rounded),
      ),
      IconButton(
        tooltip: 'Delete forever',
        onPressed: _selectedIds.isEmpty ? null : _bulkDeleteForever,
        icon: const Icon(Icons.delete_forever_rounded),
      ),
    ];

    if (isThreePane) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: _selectionMode
                    ? Row(
                        children: [
                          IconButton(
                            tooltip: 'Cancel selection',
                            onPressed: _clearSelection,
                            icon: const Icon(Icons.close_rounded),
                          ),
                          Expanded(
                            child: Text(
                              '${_selectedIds.length} selected',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          ...selectionActions,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Trash',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Empty trash',
                            onPressed: () => _confirmEmptyTrash(context, ref),
                            icon: const Icon(Icons.delete_forever_outlined),
                          ),
                        ],
                      ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        titleSpacing: _selectionMode ? 0 : 20,
        leading: _selectionMode
            ? IconButton(
                tooltip: 'Cancel selection',
                onPressed: _clearSelection,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Text(
          _selectionMode ? '${_selectedIds.length} selected' : 'Trash',
        ),
        actions: _selectionMode
            ? [...selectionActions, const SizedBox(width: 4)]
            : [
                IconButton(
                  tooltip: 'Empty trash',
                  onPressed: () => _confirmEmptyTrash(context, ref),
                  icon: const Icon(Icons.delete_forever_outlined),
                ),
                const SizedBox(width: 4),
              ],
      ),
      body: SafeArea(child: body),
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
      message:
          'This permanently removes the note and its files. This cannot be undone.',
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
