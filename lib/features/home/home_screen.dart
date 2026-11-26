import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/strata_palette.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/global_shortcuts.dart';
import '../../core/widgets/menu_items.dart';
import '../../core/widgets/skeleton_card.dart';
import '../../core/widgets/toasts.dart';
import '../../data/models/note.dart';
import '../../providers/core_providers.dart';
import '../../providers/notes_providers.dart';
import '../editor/editor_screen.dart';
import '../search/inline_search_panel.dart';
import 'widgets/folder_tree.dart';
import 'widgets/note_tile.dart';
import '../templates/template_picker_sheet.dart';

typedef NoteTapCallback = void Function(BuildContext context, int noteId);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchFocus = FocusNode();
  final _searchCtrl = TextEditingController();

  /// When non-null on wide screens, the editor is shown inline to the right.
  int? _selectedNoteId;

  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch(bool open) {
    if (!open) ref.read(searchQueryProvider.notifier).set('');
    ref.read(searchToggleProvider.notifier).set(open);
    if (open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  /// Creates a new note from shared images and navigates to the editor.
  Future<void> _importSharedImages(List<String> paths) async {
    if (!mounted || paths.isEmpty) return;
    final note = await ref
        .read(noteActionsProvider)
        .createNote(folderId: ref.read(selectedFolderProvider));
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) continue;
      await ref
          .read(attachmentsRepositoryProvider)
          .importForNote(note.id, file);
    }
    if (mounted) await context.push('/editor/${note.id}');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final isLandscape = size.width > size.height;
    final isThreePane = width >= 1100 && isLandscape;
    final searching = ref.watch(searchToggleProvider);

    // Handle images shared to Strata when the editor is not open.
    ref.listen<List<String>>(pendingSharedImagesProvider, (prev, next) {
      if (next.isEmpty) return;
      final paths = ref.read(pendingSharedImagesProvider.notifier).takeAll();
      _importSharedImages(paths);
    });
    ref.listen<bool>(searchToggleProvider, (prev, next) {
      if (!next && _searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
      }
    });

    if (isThreePane) {
      return _buildThreePaneList(context, searching);
    }

    final sort = ref.watch(noteSortProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: (searching || width < 640)
          ? null
          : const _NewNoteFab(),
      appBar: AppBar(
        titleSpacing: 16,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: _selectionMode
            ? IconButton(
                tooltip: 'Cancel selection',
                onPressed: _clearSelection,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: _selectionMode
            ? Text('${_selectedIds.length} selected')
            : const _Title(),
        actions: [
          if (_selectionMode) ...[
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
          ] else if (width < 1024)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () => _showFolderSheet(context, ref),
                icon: const Icon(Icons.folder_copy_outlined, size: 18),
                label: const Text('Folders'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  backgroundColor: StrataPalette.accent.withValues(alpha: .10),
                  side: BorderSide(
                    color: StrataPalette.accent.withValues(alpha: .25),
                  ),
                  foregroundColor: StrataPalette.accent,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        onTap: () =>
                            ref.read(searchToggleProvider.notifier).set(true),
                        onChanged: (v) {
                          ref.read(searchQueryProvider.notifier).set(v);
                          ref.read(searchToggleProvider.notifier).set(true);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search notes...',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: StrataPalette.onSurfaceMuted,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 42,
                          ),
                          suffixIcon: searching
                              ? IconButton(
                                  tooltip: 'Clear search',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 19,
                                  ),
                                  onPressed: () => _toggleSearch(false),
                                )
                              : null,
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                          ),
                          filled: true,
                          fillColor: StrataPalette.surfaceHigh.withValues(
                            alpha: .55,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: StrataPalette.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: StrataPalette.accent.withValues(alpha: .7),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<NoteSort>(
                    tooltip: 'Sort',
                    popUpAnimationStyle: const AnimationStyle(
                      duration: Duration(milliseconds: 140),
                      curve: Curves.easeOutCubic,
                    ),
                    menuPadding: const EdgeInsets.symmetric(vertical: 4),
                    initialValue: sort,
                    onSelected: (s) =>
                        ref.read(noteSortProvider.notifier).set(s),
                    itemBuilder: (_) => [
                      const PopupMenuItem<NoteSort>(
                        enabled: false,
                        padding: EdgeInsets.zero,
                        child: StrataMenuHeader('Sort by'),
                      ),
                      strataPopupItem(
                        value: NoteSort.updated,
                        icon: Icons.history_rounded,
                        label: 'Recently updated',
                        trailing: sort == NoteSort.updated
                            ? const Icon(
                                Icons.check_rounded,
                                size: 17,
                                color: StrataPalette.accent,
                              )
                            : null,
                      ),
                      strataPopupItem(
                        value: NoteSort.titleAsc,
                        icon: Icons.sort_by_alpha_rounded,
                        label: 'Title (A–Z)',
                        trailing: sort == NoteSort.titleAsc
                            ? const Icon(
                                Icons.check_rounded,
                                size: 17,
                                color: StrataPalette.accent,
                              )
                            : null,
                      ),
                      strataPopupItem(
                        value: NoteSort.dueDate,
                        icon: Icons.event_available_outlined,
                        label: 'By due date',
                        trailing: sort == NoteSort.dueDate
                            ? const Icon(
                                Icons.check_rounded,
                                size: 17,
                                color: StrataPalette.accent,
                              )
                            : null,
                      ),
                    ],
                    child: Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: StrataPalette.surfaceHigh.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: StrataPalette.outline),
                      ),
                      child: const Icon(Icons.sort_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  searching && ref.watch(searchQueryProvider).trim().isNotEmpty
                  ? InlineSearchPanel(
                      focusNode: _searchFocus,
                      onClose: () => _toggleSearch(false),
                      showField: false,
                    )
                  : _buildBody(width),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreePaneList(BuildContext context, bool searching) {
    final selectedNoteId = ref.watch(selectedNoteIdProvider);
    final folderId = ref.watch(selectedFolderProvider);
    final sort = ref.watch(noteSortProvider);

    String title = 'All notes';
    if (folderId != null) {
      final folders = ref.watch(foldersStreamProvider).value ?? const [];
      for (final f in folders) {
        if (f.id == folderId) {
          title = f.name;
          break;
        }
      }
    }

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
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
                          onPressed: _selectedIds.isEmpty ? null : _bulkDelete,
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'New note',
                          onPressed: () => _createNote(context),
                          icon: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: StrataPalette.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        onTap: () {
                          if (!searching) {
                            ref.read(searchToggleProvider.notifier).set(true);
                          }
                        },
                        onChanged: (v) {
                          ref.read(searchQueryProvider.notifier).set(v);
                          ref.read(searchToggleProvider.notifier).set(true);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search notes...',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: StrataPalette.onSurfaceMuted,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 42,
                          ),
                          suffixIcon: searching
                              ? IconButton(
                                  tooltip: 'Close search',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () => _toggleSearch(false),
                                )
                              : null,
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                          ),
                          filled: true,
                          fillColor: StrataPalette.surfaceHigh.withValues(
                            alpha: .65,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: StrataPalette.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: StrataPalette.accent.withValues(alpha: .7),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<NoteSort>(
                    tooltip: 'Sort',
                    popUpAnimationStyle: const AnimationStyle(
                      duration: Duration(milliseconds: 140),
                      curve: Curves.easeOutCubic,
                    ),
                    menuPadding: const EdgeInsets.symmetric(vertical: 4),
                    initialValue: sort,
                    onSelected: (s) =>
                        ref.read(noteSortProvider.notifier).set(s),
                    itemBuilder: (_) => [
                      const PopupMenuItem<NoteSort>(
                        enabled: false,
                        padding: EdgeInsets.zero,
                        child: StrataMenuHeader('Sort by'),
                      ),
                      strataPopupItem(
                        value: NoteSort.updated,
                        icon: Icons.history_rounded,
                        label: 'Recently updated',
                        trailing: sort == NoteSort.updated
                            ? const Icon(
                                Icons.check_rounded,
                                size: 17,
                                color: StrataPalette.accent,
                              )
                            : null,
                      ),
                      strataPopupItem(
                        value: NoteSort.titleAsc,
                        icon: Icons.sort_by_alpha_rounded,
                        label: 'Title (A–Z)',
                        trailing: sort == NoteSort.titleAsc
                            ? const Icon(
                                Icons.check_rounded,
                                size: 17,
                                color: StrataPalette.accent,
                              )
                            : null,
                      ),
                      strataPopupItem(
                        value: NoteSort.dueDate,
                        icon: Icons.event_available_outlined,
                        label: 'By due date',
                        trailing: sort == NoteSort.dueDate
                            ? const Icon(
                                Icons.check_rounded,
                                size: 17,
                                color: StrataPalette.accent,
                              )
                            : null,
                      ),
                    ],
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: StrataPalette.surfaceHigh.withValues(alpha: .65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: StrataPalette.outline),
                      ),
                      child: const Icon(Icons.sort_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  searching && ref.watch(searchQueryProvider).trim().isNotEmpty
                  ? InlineSearchPanel(
                      focusNode: _searchFocus,
                      onClose: () => _toggleSearch(false),
                      onNoteTap: (id) {
                        ref.read(selectedNoteIdProvider.notifier).select(id);
                      },
                      showField: false,
                    )
                  : _NotesList(
                      selectedNoteId: selectedNoteId,
                      selectionMode: _selectionMode,
                      selectedIds: _selectedIds,
                      onEnterSelection: _enterSelection,
                      onToggleSelection: _toggleSelection,
                      onNoteTap: (ctx, id) {
                        ref.read(selectedNoteIdProvider.notifier).select(id);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNote(BuildContext context) async {
    final folderId = ref.read(selectedFolderProvider);
    final choice = await showTemplatePickerSheet(context, ref);
    if (choice == null || !context.mounted) return;
    final note = await ref
        .read(noteActionsProvider)
        .createNote(
          folderId: folderId,
          title: choice.title,
          contentDelta: choice.deltaJson,
        );
    ref.read(selectedNoteIdProvider.notifier).select(note.id);
  }

  void _enterSelection(int noteId) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(noteId);
    });
  }

  void _toggleSelection(int noteId) {
    setState(() {
      if (_selectedIds.contains(noteId)) {
        _selectedIds.remove(noteId);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(noteId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

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

  Widget _buildBody(double width) {
    final list = _NotesList(
      selectionMode: _selectionMode,
      selectedIds: _selectedIds,
      onEnterSelection: _enterSelection,
      onToggleSelection: _toggleSelection,
    );

    if (width < 640) {
      return list;
    }
    if (width < 1024) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _NotesList(
            selectionMode: _selectionMode,
            selectedIds: _selectedIds,
            onEnterSelection: _enterSelection,
            onToggleSelection: _toggleSelection,
          ),
        ),
      );
    }
    if (width < 1380) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 260,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              child: FolderTree(onPicked: (_) {}),
            ),
          ),
          VerticalDivider(width: 1, color: StrataPalette.outline),
          Expanded(
            child: _NotesList(
              selectionMode: _selectionMode,
              selectedIds: _selectedIds,
              onEnterSelection: _enterSelection,
              onToggleSelection: _toggleSelection,
              onNoteTap: (context, id) => context.push('/editor/$id'),
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 240,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: FolderTree(onPicked: (_) {}),
          ),
        ),
        VerticalDivider(width: 1, color: StrataPalette.outline),
        SizedBox(
          width: 360,
          child: _NotesList(
            selectionMode: _selectionMode,
            selectedIds: _selectedIds,
            onEnterSelection: _enterSelection,
            onToggleSelection: _toggleSelection,
            onNoteTap: (ctx, id) => setState(() => _selectedNoteId = id),
            selectedNoteId: _selectedNoteId,
          ),
        ),
        VerticalDivider(width: 1, color: StrataPalette.outline),
        Expanded(
          child: _selectedNoteId != null
              ? EditorScreen(noteId: _selectedNoteId!)
              : _EditorPlaceholder(
                  onDismiss: () => setState(() => _selectedNoteId = null),
                ),
        ),
      ],
    );
  }

  Future<void> _showFolderSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      showDragHandle: false,
      elevation: 0,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final isWide = size.width >= 900;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 640 : double.infinity,
                    maxHeight: size.height * .78,
                  ),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: StrataPalette.surfaceHigh,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .06),
                          blurRadius: 20,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: StrataPalette.outlineStrong,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: StrataPalette.accent.withValues(
                                  alpha: .12,
                                ),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.folder_copy_outlined,
                                size: 19,
                                color: StrataPalette.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Folders',
                                    style: Theme.of(ctx).textTheme.titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                  ),
                                  Text(
                                    'Browse and organize your notes',
                                    style: Theme.of(ctx).textTheme.labelSmall
                                        ?.copyWith(
                                          color: StrataPalette.onSurfaceMuted,
                                          fontSize: 11,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => promptNewFolder(ctx, ref),
                              icon: const Icon(Icons.add_rounded, size: 17),
                              label: const Text('New'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                minimumSize: const Size(82, 34),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: StrataPalette.outline.withValues(alpha: .7),
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: FolderTree(
                              onPicked: (_) => Navigator.of(ctx).pop(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Title extends ConsumerWidget {
  const _Title();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedFolderProvider);
    String title = 'All notes';
    if (selected != null) {
      final folders = ref.watch(foldersStreamProvider).value ?? const [];
      for (final f in folders) {
        if (f.id == selected) title = f.name;
      }
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      // Left-aligned and allowed to fill the bar so folder names stay
      // readable; long names ellipsize instead of being squeezed out.
      child: Text(
        title,
        key: ValueKey(title),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({
    this.onNoteTap,
    this.selectedNoteId,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onEnterSelection,
    this.onToggleSelection,
  });

  final NoteTapCallback? onNoteTap;
  final int? selectedNoteId;
  final bool selectionMode;
  final Set<int> selectedIds;
  final ValueChanged<int>? onEnterSelection;
  final ValueChanged<int>? onToggleSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderId = ref.watch(selectedFolderProvider);
    final notesAsync = ref.watch(notesInFolderProvider(folderId));
    final maxWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = maxWidth > 720 && maxWidth < 1280
        ? 700.0
        : double.infinity;

    return notesAsync.when(
      loading: () => const NoteListSkeleton(),
      error: (e, _) => Center(
        child: Text('Something went wrong\n$e', textAlign: TextAlign.center),
      ),
      data: (notes) {
        if (notes.isEmpty) {
          return const _EmptyState();
        }
        final pinned = notes.where((n) => n.pinned).toList();
        final unpinned = notes.where((n) => !n.pinned).toList();
        final hasSections = pinned.isNotEmpty && unpinned.isNotEmpty;
        // Total items: notes + section headers (one per group when both exist).
        final itemCount = notes.length + (hasSections ? 2 : 0);

        Widget buildTile(Note note, int index) => NoteTile(
          note: note,
          index: index,
          selected: note.id == selectedNoteId,
          selectionMode: selectionMode,
          checked: selectedIds.contains(note.id),
          onChecked: onToggleSelection != null
              ? () => onToggleSelection!(note.id)
              : null,
          onEnterSelection: onEnterSelection != null
              ? () => onEnterSelection!(note.id)
              : null,
          onTap: selectionMode
              ? () => onToggleSelection?.call(note.id)
              : (onNoteTap != null
                    ? () => onNoteTap!(context, note.id)
                    : () => context.push('/editor/${note.id}')),
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: RefreshIndicator(
              onRefresh: () async {},
              child: hasSections
                  ? ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 4, bottom: 96),
                      itemCount: itemCount,
                      itemBuilder: (ctx, i) {
                        if (i == 0) return const _SectionHeader('Pinned');
                        if (i <= pinned.length) {
                          return buildTile(pinned[i - 1], i);
                        }
                        if (i == pinned.length + 1) {
                          return const _SectionHeader('Recent');
                        }
                        return buildTile(unpinned[i - pinned.length - 2], i);
                      },
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 4, bottom: 96),
                      itemCount: notes.length,
                      itemBuilder: (ctx, i) => buildTile(notes[i], i),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: StrataPalette.onSurfaceMuted,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassCard(
                borderRadius: 28,
                padding: const EdgeInsets.all(26),
                child: Icon(
                  Icons.sticky_note_2_outlined,
                  size: 44,
                  color: StrataPalette.accent.withValues(alpha: .8),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -5,
                end: 5,
                duration: 2200.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 18),
          Text(
            'No notes here yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to capture your first thought.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: StrataPalette.onSurfaceMuted,
            ),
          ),
        ],
      ),
    ).entrance(index: 0);
  }
}

class _NewNoteFab extends ConsumerWidget {
  const _NewNoteFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
          label: 'Create new note',
          button: true,
          child: FloatingActionButton(
            tooltip: 'New note',
            elevation: 3,
            highlightElevation: 5,
            backgroundColor: StrataPalette.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onPressed: () async {
              final folderId = ref.read(selectedFolderProvider);
              final choice = await showTemplatePickerSheet(context, ref);
              if (choice == null || !context.mounted) return;
              final note = await ref
                  .read(noteActionsProvider)
                  .createNote(
                    folderId: folderId,
                    title: choice.title,
                    contentDelta: choice.deltaJson,
                  );
              if (context.mounted) await context.push('/editor/${note.id}');
            },
            child: const Icon(Icons.add_rounded, size: 26),
          ),
        )
        .animate()
        .scale(
          begin: const Offset(.4, .4),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
          duration: 420.ms,
        )
        .fadeIn(duration: 260.ms);
  }
}

/// Empty-state shown in the editor pane when no note is selected.
class _EditorPlaceholder extends StatelessWidget {
  const _EditorPlaceholder({this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 48,
            color: StrataPalette.onSurfaceMuted.withValues(alpha: .35),
          ),
          const SizedBox(height: 14),
          Text(
            'Select a note to edit',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: StrataPalette.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '⌘N to create a new note',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: StrataPalette.onSurfaceMuted.withValues(alpha: .5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
