import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/strata_palette.dart';
import '../../../core/widgets/menu_items.dart';
import '../../../core/widgets/toasts.dart';
import '../../../data/models/note_folder.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/folder_counts.dart';
import '../../../providers/notes_providers.dart';

class SelectedFolder extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedFolderProvider = NotifierProvider<SelectedFolder, int?>(
  SelectedFolder.new,
);

class FolderTree extends ConsumerStatefulWidget {
  const FolderTree({
    super.key,
    this.onPicked,
    this.compact = false,
    this.showAllNotesRow = true,
  });

  final ValueChanged<NoteFolder?>? onPicked;
  final bool compact;
  final bool showAllNotesRow;

  @override
  ConsumerState<FolderTree> createState() => _FolderTreeState();
}

class _FolderTreeState extends ConsumerState<FolderTree> {
  final Set<int?> _expanded = {null};

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(foldersStreamProvider).value ?? const [];
    final selected = ref.watch(selectedFolderProvider);
    final counts = ref.watch(folderNoteCountProvider).value ?? const {};
    final byParent = <int?, List<NoteFolder>>{};
    for (final f in folders) {
      byParent.putIfAbsent(f.parentId, () => []).add(f);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showAllNotesRow)
          _Row(
            label: 'All notes',
            icon: Icons.folder_copy_outlined,
            depth: 0,
            compact: widget.compact,
            selected: selected == null,
            count: counts[null],
            onTap: () {
              ref.read(selectedFolderProvider.notifier).select(null);
              widget.onPicked?.call(null);
            },
          ),
        for (final root in byParent[null] ?? const <NoteFolder>[])
          _node(context, root, byParent, widget.showAllNotesRow ? 1 : 0, selected, counts),
      ],
    );
  }

  Widget _node(
    BuildContext context,
    NoteFolder folder,
    Map<int?, List<NoteFolder>> byParent,
    int depth,
    int? selected,
    Map<int?, int> counts,
  ) {
    final children = byParent[folder.id] ?? const <NoteFolder>[];
    final isExpanded = _expanded.contains(folder.id);
    final isSelected = selected == folder.id;

    return Column(
      key: ValueKey('folder-${folder.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(
          label: folder.name,
          icon: isExpanded && children.isNotEmpty
              ? Icons.folder_open_rounded
              : Icons.folder_rounded,
          color: Color(folder.colorValue),
          depth: depth,
          compact: widget.compact,
          selected: isSelected,
          count: counts[folder.id],
          hasChildren: children.isNotEmpty,
          expanded: isExpanded,
          onToggle: children.isEmpty
              ? null
              : () => setState(
                  () => isExpanded
                      ? _expanded.remove(folder.id)
                      : _expanded.add(folder.id),
                ),
          onTap: () {
            ref.read(selectedFolderProvider.notifier).select(folder.id);
            widget.onPicked?.call(folder);
          },
          onMenuSelected: (value) => _menu(value, folder),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOutCubic,
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            children: [
              for (final child in children)
                _node(context, child, byParent, depth + 1, selected, counts),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _menu(String value, NoteFolder folder) async {
    final folders = ref.read(foldersRepositoryProvider);
    switch (value) {
      case 'new':
        await promptNewFolder(context, ref, parentId: folder.id);
      case 'rename':
        final controller = TextEditingController(text: folder.name);
        final name = await promptText(
          context,
          title: 'Rename folder',
          hint: 'Folder name',
          controller: controller,
        );
        if (name != null && name.trim().isNotEmpty) {
          await folders.rename(folder, name.trim());
        }
        controller.dispose();
      case 'color':
        final picked = await showDialog<int>(
          context: context,
          builder: (ctx) {
            const colors = <int>[
              0xFF5B5BD6, // purple
              0xFF3B82F6, // blue
              0xFF14B8A6, // teal
              0xFF22C55E, // green
              0xFFF59E0B, // amber
              0xFFEF4444, // red
              0xFFEC4899, // pink
              0xFF8B5CF6, // violet
            ];
            return AlertDialog(
              title: const Text('Folder color'),
              content: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in colors)
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(c),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: folder.colorValue == c
                                ? Theme.of(ctx).colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: folder.colorValue == c
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ],
            );
          },
        );
        if (picked != null) {
          await folders.updateColor(folder, picked);
        }
      case 'delete':
        await folders.deletePromotingChildren(folder.id);
        ref.read(selectedFolderProvider.notifier).select(null);
        showToast(ref, 'Folder deleted, contents moved up');
    }
  }
}

Future<void> promptNewFolder(
  BuildContext context,
  WidgetRef ref, {
  int? parentId,
}) async {
  final name = await promptText(
    context,
    title: 'New folder',
    hint: 'Folder name',
  );
  if (name != null && name.trim().isNotEmpty) {
    await ref
        .read(foldersRepositoryProvider)
        .create(name.trim(), parentId, StrataPalette.accent.toARGB32());
    if (context.mounted) showToast(ref, 'Folder created');
  }
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String hint,
  TextEditingController? controller,
}) {
  final own = controller ?? TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: own,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(own.text),
          child: const Text('Save'),
        ),
      ],
    ),
  ).whenComplete(() {
    if (controller == null) own.dispose();
  });
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.icon,
    required this.depth,
    required this.selected,
    required this.compact,
    this.color,
    this.count,
    this.hasChildren = false,
    this.expanded = false,
    this.onTap,
    this.onToggle,
    this.onMenuSelected,
  });

  final String label;
  final IconData icon;
  final Color? color;
  final int? count;
  final int depth;
  final bool selected;
  final bool compact;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final ValueChanged<String>? onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folderColor = color ?? StrataPalette.accent;
    final semanticsLabel = '${count != null ? "$count notes. " : ""}'
        '${selected ? "Selected. " : ""}'
        '${hasChildren ? (expanded ? "Expanded." : "Collapsed.") : ''}';

    return Padding(
      padding: EdgeInsets.only(
        left: compact ? 0 : depth * 14.0,
        bottom: 2,
      ),
      child: Semantics(
        label: '$label. $semanticsLabel',
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? folderColor.withValues(alpha: .13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: folderColor.withValues(alpha: .18))
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: hasChildren
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onToggle,
                              child: AnimatedRotation(
                                turns: expanded ? .25 : 0,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: folderColor.withValues(
                          alpha: selected ? .18 : .10,
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, size: 16, color: folderColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                          color: selected
                              ? folderColor
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (count != null)
                      Container(
                        width: 24,
                        height: 22,
                        margin: const EdgeInsets.only(left: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: folderColor.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: folderColor,
                          ),
                        ),
                      ),
                    if (onMenuSelected != null)
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: PopupMenuButton<String>(
                          onSelected: onMenuSelected,
                          color: StrataPalette.surfaceHighest,
                          elevation: 2,
                          offset: const Offset(0, 34),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          constraints: const BoxConstraints(minWidth: 180),
                          itemBuilder: (_) => [
                            strataPopupItem(
                              value: 'new',
                              icon: Icons.create_new_folder_outlined,
                              label: 'New subfolder',
                            ),
                            strataPopupItem(
                              value: 'rename',
                              icon: Icons.drive_file_rename_outline_rounded,
                              label: 'Rename',
                            ),
                            strataPopupItem(
                              value: 'color',
                              icon: Icons.palette_outlined,
                              label: 'Change color',
                            ),
                            strataPopupItem(
                              value: 'delete',
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              danger: true,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
