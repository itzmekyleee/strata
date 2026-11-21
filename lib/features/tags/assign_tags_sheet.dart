import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/strata_palette.dart';
import '../../data/models/tag.dart';
import '../../providers/core_providers.dart';
import '../../providers/notes_providers.dart';

Future<void> showAssignTagsSheet(BuildContext context, int noteId) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // Keep the sheet clear of the floating navigation dock.
    useSafeArea: true,
    builder: (_) => _AssignTagsSheet(noteId: noteId),
  );
}

class _AssignTagsSheet extends ConsumerStatefulWidget {
  const _AssignTagsSheet({required this.noteId});

  final int noteId;

  @override
  ConsumerState<_AssignTagsSheet> createState() => _AssignTagsSheetState();
}

class _AssignTagsSheetState extends ConsumerState<_AssignTagsSheet> {
  Set<int>? _selected;
  List<Tag>? _all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ref.read(tagsStreamProvider.future);
    final note = await ref.read(notesRepositoryProvider).getById(widget.noteId);
    final current = note == null
        ? <Tag>[]
        : await ref.read(tagsRepositoryProvider).tagsForNote(note);
    if (!mounted) return;
    setState(() {
      _all = all;
      _selected = {for (final t in current) t.id};
    });
  }

  Future<void> _persist() async {
    final selected = _selected ?? const <int>{};
    final all = _all ?? const <Tag>[];
    final tags = [
      for (final t in all)
        if (selected.contains(t.id)) t,
    ];
    final note = await ref.read(notesRepositoryProvider).getById(widget.noteId);
    if (note != null) {
      await ref.read(tagsRepositoryProvider).setTagsForNote(note, tags);
    }
  }

  Future<void> _createTag() async {
    final created = await showCreateTagDialog(context);
    if (created != null) {
      final all = [...(_all ?? const <Tag>[]), created];
      setState(() => _all = all);
      _selected!.add(created.id);
      await _persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    if (all == null || _selected == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tags', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in all)
                  FilterChip(
                    label: Text(tag.name),
                    selected: _selected!.contains(tag.id),
                    onSelected: (v) {
                      setState(
                        () => v
                            ? _selected!.add(tag.id)
                            : _selected!.remove(tag.id),
                      );
                      _persist();
                    },
                    avatar: CircleAvatar(
                      backgroundColor: Color(tag.colorValue),
                      radius: 5,
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('New tag'),
                  onPressed: _createTag,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<Tag?> showCreateTagDialog(BuildContext context) async {
  final ref = ProviderScope.containerOf(context);
  final controller = TextEditingController();
  var color = StrataPalette.tagSwatches.first;

  final result = await showDialog<Tag>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('New tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Tag name'),
              onSubmitted: (_) => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final swatch in StrataPalette.tagSwatches)
                  GestureDetector(
                    onTap: () => setDialogState(() => color = swatch),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(swatch),
                        border: color == swatch
                            ? Border.all(color: Colors.white, width: 2.4)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final tag = await ref
                  .read(tagsRepositoryProvider)
                  .create(name, color);
              if (ctx.mounted) Navigator.of(ctx).pop(tag);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}
