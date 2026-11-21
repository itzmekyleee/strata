import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/strata_palette.dart';
import '../../../core/widgets/toasts.dart';
import '../../../data/models/note.dart';
import '../../../data/services/delta_to_markdown.dart';
import '../../../providers/core_providers.dart';
import '../../tags/assign_tags_sheet.dart';
import '../widgets/folder_tree.dart';

Future<void> showNoteActionsSheet(BuildContext context, Note note) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Keep the sheet clear of the floating navigation dock.
    useSafeArea: true,
    builder: (ctx) => _NoteActionsSheet(note: note),
  );
}

class _NoteActionsSheet extends ConsumerStatefulWidget {
  const _NoteActionsSheet({required this.note});

  final Note note;

  @override
  ConsumerState<_NoteActionsSheet> createState() => _NoteActionsSheetState();
}

class _NoteActionsSheetState extends ConsumerState<_NoteActionsSheet> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.note.title.trim().isEmpty
                  ? 'Untitled'
                  : widget.note.title.trim(),
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            _Action(
              icon: Icons.drive_file_move_outline,
              label: 'Move to folder…',
              onTap: () async {
                Navigator.of(context).pop();
                await pickFolderAndMove(context, ref, widget.note);
              },
            ),
            _Action(
              icon: Icons.style_outlined,
              label: 'Manage tags…',
              onTap: () {
                Navigator.of(context).pop();
                showAssignTagsSheet(context, widget.note.id);
              },
            ),
            _Action(
              icon: Icons.push_pin_outlined,
              label: widget.note.pinned ? 'Unpin' : 'Pin to top',
              onTap: () async {
                Navigator.of(context).pop();
                final repo = ref.read(notesRepositoryProvider);
                final fresh = await repo.getById(widget.note.id);
                if (fresh != null) {
                  fresh.pinned = !fresh.pinned;
                  await repo.save(fresh);
                }
              },
            ),
            _Action(
              icon: Icons.picture_as_pdf_outlined,
              label: 'Export as PDF',
              onTap: () async {
                Navigator.of(context).pop();
                await exportPdf(context, ref, widget.note.id);
              },
            ),
            _Action(
              icon: Icons.description_outlined,
              label: 'Export as Markdown',
              onTap: () async {
                Navigator.of(context).pop();
                await exportMarkdown(context, ref, widget.note.id);
              },
            ),
            _Action(
              icon: Icons.article_outlined,
              label: 'Export as Word',
              onTap: () async {
                Navigator.of(context).pop();
                await exportDocx(context, ref, widget.note.id);
              },
            ),
            _Action(
              icon: Icons.delete_outline_rounded,
              label: 'Move to trash',
              destructive: true,
              onTap: () async {
                Navigator.of(context).pop();
                final noteId = widget.note.id;
                await ref.read(noteActionsProvider).trash(noteId);
                showUndoToast(
                  ref,
                  'Moved to trash',
                  onUndo: () async {
                    await ref.read(noteActionsProvider).restore(noteId);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? StrataPalette.coral
        : Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 21, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the full folder tree; picking one moves [note] there.
Future<void> pickFolderAndMove(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  int? chosen = note.folderId;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // Keep the sheet clear of the floating navigation dock.
    useSafeArea: true,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: .7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Move “${note.title.isEmpty ? 'Untitled' : note.title}”',
              style: Theme.of(ctx).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setSheetState) => FolderTree(
                    compact: true,
                    onPicked: (folder) =>
                        setSheetState(() => chosen = folder?.id),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Move here'),
            ),
          ],
        ),
      ),
    ),
  );
  if (confirmed == true && context.mounted) {
    final repo = ref.read(notesRepositoryProvider);
    final fresh = await repo.getById(note.id);
    if (fresh != null) {
      fresh.folderId = chosen;
      await repo.save(fresh);
      if (context.mounted) showToast(ref, 'Note moved');
    }
  }
}

Future<void> exportPdf(
  BuildContext context,
  WidgetRef ref,
  int noteId, {
  double lineHeight = 1.55,
  double paraSpacing = 4.0,
}) async {
  try {
    final note = await ref.read(notesRepositoryProvider).getById(noteId);
    if (note == null) return;
    final bytes = await ref
        .read(pdfConverterProvider)
        .exportNote(note, lineHeight: lineHeight, paraSpacing: paraSpacing);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_safeName(note.title)}.pdf',
    );
    showToast(ref, 'PDF exported');
  } catch (e) {
    showToast(ref, 'Export failed: $e', type: ToastType.error);
  }
}

Future<void> exportDocx(
  BuildContext context,
  WidgetRef ref,
  int noteId, {
  double lineHeight = 1.55,
  double paraSpacing = 4.0,
}) async {
  try {
    final note = await ref.read(notesRepositoryProvider).getById(noteId);
    if (note == null) return;
    final bytes = await ref
        .read(docxConverterProvider)
        .exportNote(note, lineHeight: lineHeight, paraSpacing: paraSpacing);
    final file = File(
      '${Directory.systemTemp.path}/${_safeName(note.title)}.docx',
    );
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Word export'),
    );
    showToast(ref, 'Word document exported');
  } catch (e) {
    showToast(ref, 'Export failed: $e', type: ToastType.error);
  }
}

Future<void> exportMarkdown(
  BuildContext context,
  WidgetRef ref,
  int noteId,
) async {
  try {
    final note = await ref.read(notesRepositoryProvider).getById(noteId);
    if (note == null) return;
    final md = DeltaToMarkdown.convert(note.contentDelta, title: note.title);
    final file = File(
      '${Directory.systemTemp.path}/${_safeName(note.title)}.md',
    );
    await file.writeAsString(md, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/markdown')],
        text: 'Markdown export',
      ),
    );
    showToast(ref, 'Markdown exported');
  } catch (e) {
    showToast(ref, 'Export failed: $e', type: ToastType.error);
  }
}

String _safeName(String title) {
  final t = title.trim().isEmpty ? 'Untitled' : title.trim();
  final clean = t.replaceAll(RegExp(r'[^\w\- ]'), '');
  return clean.isEmpty ? 'note' : clean.substring(0, clean.length.clamp(0, 60));
}
