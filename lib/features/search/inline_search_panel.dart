import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/strata_palette.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/toasts.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/notes_providers.dart';
import '../home/widgets/folder_tree.dart';
import '../home/widgets/note_tile.dart';

/// Inline search that lives on the Home screen instead of its own page.
///
/// The magnifier and the clear button sit *inside* the text field via
/// [InputDecoration.prefixIcon]/[suffixIcon], so the focus ring wraps the
/// whole control instead of stopping short at either side.
class InlineSearchPanel extends ConsumerStatefulWidget {
  const InlineSearchPanel({
    super.key,
    required this.focusNode,
    required this.onClose,
    this.onNoteTap,
    this.showField = true,
  });

  final FocusNode focusNode;
  final VoidCallback onClose;
  final ValueChanged<int>? onNoteTap;
  final bool showField;

  @override
  ConsumerState<InlineSearchPanel> createState() => _InlineSearchPanelState();
}

class _InlineSearchPanelState extends ConsumerState<InlineSearchPanel> {
  late final TextEditingController _ctrl;
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
    _ctrl.addListener(() {
      ref.read(searchQueryProvider.notifier).set(_ctrl.text);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                  child: FolderTree(showAllNotesRow: false, onPicked: (f) => Navigator.of(ctx).pop(f?.id)),
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
      showToast(ref, 'Moved ${_selectedIds.length} note${_selectedIds.length == 1 ? '' : 's'}');
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final theme = Theme.of(context);

    final resultsBody = results.when(
            loading: () => const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              if (query.trim().isEmpty) {
                return Center(
                  child: Text(
                    'Type to search across all notes',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: StrataPalette.onSurfaceMuted,
                    ),
                  ),
                );
              }
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'No matches for “$query”',
                    style: theme.textTheme.titleMedium,
                  ),
                );
              }
              return Column(
                children: [
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                      child: Row(
                        children: [
                          IconButton(tooltip: 'Cancel selection', onPressed: _clearSelection, icon: const Icon(Icons.close_rounded)),
                          Expanded(child: Text('${_selectedIds.length} selected', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                          IconButton(tooltip: 'Move', onPressed: _selectedIds.isEmpty ? null : _bulkMove, icon: const Icon(Icons.drive_file_move_outlined)),
                          IconButton(tooltip: 'Delete', onPressed: _selectedIds.isEmpty ? null : _bulkDelete, icon: const Icon(Icons.delete_outline_rounded)),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 40),
                      itemCount: list.length,
                      itemBuilder: (context, i) => NoteTile(
                        note: list[i],
                        index: i,
                        highlightQuery: query,
                        selectionMode: _selectionMode,
                        checked: _selectedIds.contains(list[i].id),
                        onChecked: () => _toggleSelection(list[i].id),
                        onEnterSelection: () => _enterSelection(list[i].id),
                        onTap: _selectionMode
                            ? () => _toggleSelection(list[i].id)
                            : (widget.onNoteTap != null ? () => widget.onNoteTap!(list[i].id) : null),
                      ),
                    ),
                  ),
                ],
              );
            },
          );

    if (!widget.showField) {
      return resultsBody;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: TextField(
            focusNode: widget.focusNode,
            autofocus: true,
            controller: _ctrl,
            style: const TextStyle(fontSize: 15.5),
            decoration: InputDecoration(
              hintText: 'Search titles and content…',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: StrataPalette.onSurfaceMuted,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 42),
              suffixIcon: query.isEmpty
                  ? IconButton(
                      tooltip: 'Close search',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 19),
                      onPressed: widget.onClose,
                    )
                  : IconButton(
                      tooltip: 'Clear',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 19),
                      onPressed: () {
                        _ctrl.clear();
                        widget.focusNode.requestFocus();
                      },
                    ),
              suffixIconConstraints: const BoxConstraints(minWidth: 40),
              filled: true,
              fillColor: StrataPalette.surfaceHigh.withValues(alpha: .55),
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: StrataPalette.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: StrataPalette.accent,
                  width: 1.5,
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 200.ms)
              .slideY(begin: -.12, end: 0, curve: Curves.easeOutCubic),
        ),
        Expanded(child: resultsBody),
      ],
    );
  }
}
