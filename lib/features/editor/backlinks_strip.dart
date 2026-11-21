import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/strata_palette.dart';
import '../../providers/notes_providers.dart';

/// Slim horizontal strip under the editor listing notes that link to the
/// currently open note ("Referenced by"). Hidden when there are none.
class BacklinksStrip extends ConsumerWidget {
  const BacklinksStrip({super.key, required this.noteId});

  final int noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linksAsync = ref.watch(backlinksProvider(noteId));
    final links = linksAsync.value ?? const [];
    if (links.isEmpty) return const SizedBox.shrink();

    return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: StrataPalette.outline),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_tree_rounded,
                size: 14,
                color: StrataPalette.onSurfaceMuted,
              ),
              const SizedBox(width: 7),
              Text(
                'Referenced by',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: StrataPalette.onSurfaceMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: links.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final n = links[i];
                      return ActionChip(
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: StrataPalette.accent.withValues(alpha: .35),
                        ),
                        avatar: Icon(
                          Icons.article_outlined,
                          size: 14,
                          color: StrataPalette.accent,
                        ),
                        label: Text(
                          n.title.trim().isEmpty ? 'Untitled' : n.title.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => context.push('/editor/${n.id}'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 220.ms)
        .slideY(
          begin: .3,
          end: 0,
          duration: 260.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
