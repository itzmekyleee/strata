import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/strata_palette.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/global_shortcuts.dart';
import '../../core/widgets/menu_items.dart';
import '../../core/widgets/skeleton_card.dart';
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

  /// When non-null on wide screens, the editor is shown inline to the right.
  int? _selectedNoteId;

  @override
  void dispose() {
    _searchFocus.dispose();
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
    final width = MediaQuery.sizeOf(context).width;
    final searching = ref.watch(searchToggleProvider);

    // Handle images shared to Strata when the editor is not open.
    ref.listen<List<String>>(pendingSharedImagesProvider, (prev, next) {
      if (next.isEmpty) return;
      final paths = ref.read(pendingSharedImagesProvider.notifier).takeAll();
      _importSharedImages(paths);
    });

    return Scaffold(
      floatingActionButton: searching ? null : const _NewNoteFab(),
      appBar: AppBar(
        titleSpacing: 16,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: searching ? null : const _Title(),
        actions: [
          if (!searching) ...[
            if (width < 1024)
              IconButton(
                tooltip: 'Folders',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showFolderSheet(context, ref),
                icon: const Icon(Icons.folder_copy_outlined),
              ),
            IconButton(
              tooltip: 'Search',
              visualDensity: VisualDensity.compact,
              onPressed: () => _toggleSearch(true),
              icon: const Icon(Icons.search_rounded),
            ),
            PopupMenuButton<NoteSort>(
              tooltip: 'Sort',
              icon: const Icon(Icons.sort_rounded),
              constraints: const BoxConstraints(minWidth: 216, maxWidth: 240),
              onSelected: (s) => ref.read(noteSortProvider.notifier).set(s),
              itemBuilder: (_) {
                Widget check(NoteSort s) => Icon(
                  Icons.check_rounded,
                  size: 17,
                  color: ref.read(noteSortProvider) == s
                      ? StrataPalette.accent
                      : Colors.transparent,
                );
                return [
                  const PopupMenuItem<NoteSort>(
                    enabled: false,
                    padding: EdgeInsets.zero,
                    child: StrataMenuHeader('Sort by'),
                  ),
                  strataPopupItem(
                    value: NoteSort.updated,
                    icon: Icons.history_rounded,
                    label: 'Recently updated',
                    trailing: check(NoteSort.updated),
                  ),
                  strataPopupItem(
                    value: NoteSort.titleAsc,
                    icon: Icons.sort_by_alpha_rounded,
                    label: 'Title (A–Z)',
                    trailing: check(NoteSort.titleAsc),
                  ),
                  strataPopupItem(
                    value: NoteSort.dueDate,
                    icon: Icons.event_available_outlined,
                    label: 'By due date',
                    trailing: check(NoteSort.dueDate),
                  ),
                ];
              },
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: searching
            ? InlineSearchPanel(
                focusNode: _searchFocus,
                onClose: () => _toggleSearch(false),
              )
            : _buildBody(width),
      ),
    );
  }

  Widget _buildBody(double width) {
    if (width < 640) {
      return const _NotesList();
    }
    if (width < 1024) {
      // Tablet portrait / medium width: single column with breathing room.
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: const _NotesList(),
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
          VerticalDivider(
            width: 1,
            color: StrataPalette.outline,
          ),
          Expanded(
            child: _NotesList(
              onNoteTap: (context, id) => context.push('/editor/$id'),
            ),
          ),
        ],
      );
    }
    // Wide screen: folder tree | notes list | editor pane
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
        VerticalDivider(
          width: 1,
          color: StrataPalette.outline,
        ),
        SizedBox(
          width: 360,
          child: _NotesList(
            onNoteTap: (ctx, id) {
              setState(() => _selectedNoteId = id);
            },
            selectedNoteId: _selectedNoteId,
          ),
        ),
        VerticalDivider(
          width: 1,
          color: StrataPalette.outline,
        ),
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
      showDragHandle: true,
      isScrollControlled: true,
      // Keep the sheet clear of the floating navigation dock.
      useSafeArea: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: .72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Folders', style: Theme.of(ctx).textTheme.titleLarge),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => promptNewFolder(context, ref),
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 19,
                    ),
                    label: const Text('New'),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: FolderTree(onPicked: (_) => Navigator.of(ctx).pop()),
                ),
              ),
            ],
          ),
        ),
      ),
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
  const _NotesList({this.onNoteTap, this.selectedNoteId});

  final NoteTapCallback? onNoteTap;
  final int? selectedNoteId;

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
              onTap: onNoteTap != null
                  ? () => onNoteTap!(context, note.id)
                  : () => context.push('/editor/${note.id}'),
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
                        return buildTile(
                          unpinned[i - pinned.length - 2],
                          i,
                        );
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
