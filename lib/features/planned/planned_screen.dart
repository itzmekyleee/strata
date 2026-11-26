import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/strata_palette.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/skeleton_card.dart';
import '../../core/widgets/toasts.dart';
import '../../data/models/note.dart';
import '../../providers/core_providers.dart';
import '../../providers/notes_providers.dart';
import '../home/widgets/folder_tree.dart';
import '../home/widgets/note_tile.dart';

/// Upcoming reminders: every active note with a due date, grouped by how
/// soon it is due.
class PlannedScreen extends ConsumerStatefulWidget {
  const PlannedScreen({super.key});

  @override
  ConsumerState<PlannedScreen> createState() => _PlannedScreenState();
}

class _PlannedScreenState extends ConsumerState<PlannedScreen> {
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

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete $count note${count == 1 ? '' : 's'}?',
      message: 'Selected notes will be moved to trash.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed != true) return;
    final actions = ref.read(noteActionsProvider);
    for (final id in _selectedIds.toList()) {
      await actions.trash(id);
    }
    if (mounted) {
      showToast(ref, '$count note${count == 1 ? '' : 's'} moved to trash');
      _clearSelection();
    }
  }

  Future<void> _bulkMove() async {
    final folderId = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: .6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Move to folder', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.folder_copy_outlined),
                title: const Text('All notes (no folder)'),
                onTap: () => Navigator.of(ctx).pop(-1),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: FolderTree(
                    showAllNotesRow: false,
                    onPicked: (f) => Navigator.of(ctx).pop(f?.id),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (folderId == null) return;
    final target = folderId == -1 ? null : folderId;
    final repo = ref.read(notesRepositoryProvider);
    for (final id in _selectedIds.toList()) {
      final note = await repo.getById(id);
      if (note == null) continue;
      note.folderId = target;
      await repo.save(note);
    }
    if (mounted) {
      showToast(
        ref,
        'Moved ${_selectedIds.length} note${_selectedIds.length == 1 ? '' : 's'}',
      );
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final plannedAsync = ref.watch(plannedNotesProvider);
    final size = MediaQuery.sizeOf(context);
    final isThreePane = size.width >= 1100 && size.width > size.height;
    final selectedNoteId = isThreePane
        ? ref.watch(selectedNoteIdProvider)
        : null;

    final body = plannedAsync.when(
      loading: () => const NoteListSkeleton(),
      error: (e, _) => Center(
        child: Text('Something went wrong\n$e', textAlign: TextAlign.center),
      ),
      data: (notes) => _PlannedList(
        notes: notes,
        isThreePane: isThreePane,
        selectedNoteId: selectedNoteId,
        selectionMode: _selectionMode,
        selectedIds: _selectedIds,
        onEnterSelection: _enterSelection,
        onToggleSelection: _toggleSelection,
      ),
    );

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
                          IconButton(
                            tooltip: 'Move',
                            onPressed: _selectedIds.isEmpty ? null : _bulkMove,
                            icon: const Icon(Icons.drive_file_move_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: _selectedIds.isEmpty
                                ? null
                                : _bulkDelete,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      )
                    : Text(
                        'Planned',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
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
          _selectionMode ? '${_selectedIds.length} selected' : 'Planned',
          style: _selectionMode
              ? null
              : Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: _selectionMode
            ? [
                IconButton(
                  tooltip: 'Move',
                  onPressed: _selectedIds.isEmpty ? null : _bulkMove,
                  icon: const Icon(Icons.drive_file_move_outlined),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _selectedIds.isEmpty ? null : _bulkDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ]
            : null,
      ),
      body: SafeArea(child: body),
    );
  }
}

class _PlannedList extends ConsumerWidget {
  const _PlannedList({
    required this.notes,
    required this.isThreePane,
    required this.selectedNoteId,
    required this.selectionMode,
    required this.selectedIds,
    required this.onEnterSelection,
    required this.onToggleSelection,
  });

  final List<Note> notes;
  final bool isThreePane;
  final int? selectedNoteId;
  final bool selectionMode;
  final Set<int> selectedIds;
  final ValueChanged<int> onEnterSelection;
  final ValueChanged<int> onToggleSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 46,
              color: StrataPalette.accent.withValues(alpha: .8),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing scheduled',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Reminders you set on notes show up here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: StrataPalette.onSurfaceMuted,
              ),
            ),
          ],
        ).entrance(index: 0),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <(String, Color, List<Note>)>[];
    void add(String label, Color color, bool Function(DateTime due) match) {
      final hits = [
        for (final n in notes)
          if (match(
            DateTime(n.dueDate!.year, n.dueDate!.month, n.dueDate!.day),
          ))
            n,
      ];
      if (hits.isNotEmpty) groups.add((label, color, hits));
    }

    add('Overdue', StrataPalette.coral, (d) => d.isBefore(today));
    add('Today', StrataPalette.amber, (d) => d.isAtSameMomentAs(today));
    add(
      'Upcoming',
      StrataPalette.accent,
      (d) => d.isAfter(today) && d.isBefore(today.add(const Duration(days: 7))),
    );

    final upcomingEnd = today.add(const Duration(days: 7));
    final later = [
      for (final n in notes)
        if (!DateTime(
          n.dueDate!.year,
          n.dueDate!.month,
          n.dueDate!.day,
        ).isBefore(upcomingEnd))
          n,
    ];
    if (later.isNotEmpty) {
      groups.add(('Later', StrataPalette.onSurfaceMuted, later));
    }

    var index = 0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isThreePane ? double.infinity : 860,
        ),
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 96),
          itemCount: groups.fold<int>(0, (n, g) => n + g.$3.length + 1),
          itemBuilder: (context, i) {
            var cursor = i;
            for (final (label, color, items) in groups) {
              if (cursor == 0) {
                return _SectionHeader(label: label, color: color);
              }
              cursor--;
              if (cursor < items.length) {
                final note = items[cursor];
                return NoteTile(
                  note: note,
                  index: index++,
                  selected: isThreePane && note.id == selectedNoteId,
                  selectionMode: selectionMode,
                  checked: selectedIds.contains(note.id),
                  onChecked: () => onToggleSelection(note.id),
                  onEnterSelection: () => onEnterSelection(note.id),
                  onTap: selectionMode
                      ? () => onToggleSelection(note.id)
                      : (isThreePane
                            ? () => ref
                                  .read(selectedNoteIdProvider.notifier)
                                  .select(note.id)
                            : null),
                );
              }
              cursor -= items.length;
            }
            throw StateError('index out of range');
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .9,
              color: StrataPalette.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}
