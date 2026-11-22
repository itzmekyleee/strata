import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/strata_palette.dart';
import '../../../core/utils/due_status.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/highlight_text.dart';
import '../../../core/widgets/toasts.dart';
import '../../../data/models/note.dart';
import '../../../data/models/tag.dart';
import '../../../providers/core_providers.dart';
import 'note_actions_sheet.dart';

class NoteTile extends ConsumerWidget {
  const NoteTile({
    super.key,
    required this.note,
    required this.index,
    this.onTap,
    this.selected = false,
    this.highlightQuery = '',
    this.selectionMode = false,
    this.checked = false,
    this.onChecked,
    this.onEnterSelection,
  });

  final Note note;
  final int index;
  final VoidCallback? onTap;
  final bool selected;
  final String highlightQuery;
  final bool selectionMode;
  final bool checked;
  final VoidCallback? onChecked;
  final VoidCallback? onEnterSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasPreview = note.plainPreview.trim().isNotEmpty;
    final dueStatus = DueStatusX.classify(note.dueDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2.5),
      child: Dismissible(
        key: ValueKey('note-${note.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: StrataPalette.coral.withValues(alpha: .18),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: StrataPalette.coral,
            size: 20,
          ),
        ),
        onDismissed: (_) async {
          await ref.read(noteActionsProvider).trash(note.id);
          // Show undo toast — if tapped, restore the note.
          showUndoToast(
            ref,
            'Moved to trash',
            onUndo: () async {
              await ref.read(noteActionsProvider).restore(note.id);
            },
          );
        },
        child: GlassCard(
          borderRadius: 16,
          padding: EdgeInsets.zero,
          borderColor: note.pinned
              ? StrataPalette.accent.withValues(alpha: .35)
              : null,
          child: Material(
            color: selected
                ? StrataPalette.accent.withValues(alpha: .08)
                : Colors.transparent,
            child: Semantics(
              label: '${note.title.trim().isEmpty ? 'Untitled' : note.title.trim()}. '
                  '${note.wordCount} words. '
                  '${note.pinned ? 'Pinned. ' : ''}'
                  'Double tap to edit. Long press for actions.',
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                splashColor: StrataPalette.accent.withValues(alpha: .08),
                highlightColor: StrataPalette.accent.withValues(alpha: .04),
                onTap: selectionMode ? onChecked : (onTap ?? () => context.push('/editor/${note.id}')),
                onLongPress: selectionMode
                    ? onChecked
                    : (onEnterSelection ?? () => showNoteActionsSheet(context, note)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (selectionMode) ...[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: checked ? StrataPalette.accent : Colors.transparent,
                              border: Border.all(
                                color: checked ? StrataPalette.accent : StrataPalette.onSurfaceMuted.withValues(alpha: .5),
                                width: 1.8,
                              ),
                            ),
                            child: checked
                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Hero(
                            tag: 'note-title-${note.id}',
                            child: HighlightText(
                              note.title.trim().isEmpty
                                  ? 'Untitled'
                                  : note.title.trim(),
                              query: highlightQuery,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize:
                                    MediaQuery.sizeOf(context).width < 640
                                    ? 14.5
                                    : 16,
                              ),
                            ),
                          ),
                        ),
                        if (note.isTrashed)
                          Icon(
                            Icons.delete_sweep_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        if (note.pinned)
                          Icon(
                            Icons.push_pin_rounded,
                            size: 15,
                            color: StrataPalette.amber,
                          ),
                      ],
                    ),
                    if (hasPreview) ...[
                      const SizedBox(height: 3),
                      HighlightText(
                        note.plainPreview.trim(),
                        query: highlightQuery,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: StrataPalette.onSurfaceMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (dueStatus != null) ...[
                          _DueChip(due: note.dueDate!, status: dueStatus),
                        ] else
                          Text(
                            _relativeDate(note.updatedAt.toLocal()),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              color: StrataPalette.onSurfaceMuted,
                            ),
                          ),
                        const Spacer(),
                        FutureTagsRow(noteId: note.id),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ),
      ),
    ).entrance(index: index.clamp(0, 12));
  }
}

String _relativeDate(DateTime local) {
  final now = DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;

  String dayLabel;
  if (diff == 0) {
    dayLabel = 'Today';
  } else if (diff == 1) {
    dayLabel = 'Yesterday';
  } else if (diff > 1 && diff < 7) {
    dayLabel = DateFormat.EEEE().format(local);
  } else {
    dayLabel = DateFormat.MMMd().format(local);
  }
  return '$dayLabel · ${DateFormat.jm().format(local)}';
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.due, required this.status});

  final DateTime due;
  final DueStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      DueStatus.overdue => (StrataPalette.coral, Icons.alarm_rounded),
      DueStatus.today => (
        StrataPalette.amber,
        Icons.notifications_active_rounded,
      ),
      DueStatus.upcoming => (
        StrataPalette.mint,
        Icons.notifications_none_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: .14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            DueStatusX.labelFor(due),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class FutureTagsRow extends ConsumerStatefulWidget {
  const FutureTagsRow({super.key, required this.noteId});

  final int noteId;

  @override
  ConsumerState<FutureTagsRow> createState() => _FutureTagsRowState();
}

class _FutureTagsRowState extends ConsumerState<FutureTagsRow> {
  List<Tag>? tags;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FutureTagsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId) _load();
  }

  Future<void> _load() async {
    final note = await ref.read(notesRepositoryProvider).getById(widget.noteId);
    if (note == null) return;
    final t = await ref.read(tagsRepositoryProvider).tagsForNote(note);
    if (mounted) setState(() => tags = t);
  }

  @override
  Widget build(BuildContext context) {
    final list = tags ?? const <Tag>[];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tag in list.take(3))
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(tag.colorValue),
            ),
          ),
      ],
    );
  }
}
