import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/strata_palette.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/skeleton_card.dart';
import '../../providers/core_providers.dart';
import '../../providers/notes_providers.dart';
import 'assign_tags_sheet.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage tags')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateTagDialog(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: tagsAsync.when(
          loading: () => const SkeletonBox(
            child: Column(
              children: [
                TagRowSkeleton(),
                TagRowSkeleton(),
                TagRowSkeleton(),
                TagRowSkeleton(),
              ],
            ),
          ),
          error: (e, _) => Center(child: Text('$e')),
          data: (tags) {
            if (tags.isEmpty) {
              return Center(
                child: Text(
                  'No tags yet — create one to start organizing.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: StrataPalette.onSurfaceMuted,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: tags.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final tag = tags[i];
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: StrataPalette.outline,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(tag.colorValue),
                        boxShadow: [
                          BoxShadow(
                            color: Color(tag.colorValue).withValues(alpha: .5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    title: Text(
                      tag.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Rename',
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () async {
                            // Reuses create dialog flow via rename prompt.
                            final controller = TextEditingController(
                              text: tag.name,
                            );
                            await showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Rename tag'),
                                content: TextField(controller: controller),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () async {
                                      final name = controller.text.trim();
                                      if (name.isNotEmpty) {
                                        await ref
                                            .read(tagsRepositoryProvider)
                                            .rename(tag, name, tag.colorValue);
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    },
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                            controller.dispose();
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: StrataPalette.coral.withValues(alpha: .9),
                          ),
                          onPressed: () async {
                            await ref.read(tagsRepositoryProvider).delete(tag);
                          },
                        ),
                      ],
                    ),
                  ),
                ).entrance(index: i);
              },
            );
          },
        ),
      ),
    );
  }
}
