import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../app/theme/strata_palette.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/note.dart';

/// Floating panel above the keyboard listing note titles while the user
/// types a `[[wiki link` fragment.
class WikiSuggestPanel extends StatelessWidget {
  const WikiSuggestPanel({
    super.key,
    required this.suggestions,
    required this.onPicked,
  });

  final List<Note> suggestions;
  final ValueChanged<Note> onPicked;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.MMMd();
    return GlassCard(
          borderRadius: 18,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 264),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Text(
                    'LINK TO',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: StrataPalette.onSurfaceMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
                if (suggestions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'No matching notes. Close with ]] — it will link '
                      'automatically once a note with this title exists.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: StrataPalette.onSurfaceMuted,
                        height: 1.35,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: suggestions.length,
                      itemBuilder: (context, i) {
                        final n = suggestions[i];
                        return InkWell(
                          onTap: () => onPicked(n),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.article_outlined,
                                  size: 17,
                                  color: StrataPalette.accent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    n.title.trim().isEmpty
                                        ? 'Untitled'
                                        : n.title.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  dateFmt.format(n.updatedAt.toLocal()),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: StrataPalette.onSurfaceMuted,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 140.ms)
        .moveY(begin: 12, end: 0, duration: 200.ms, curve: Curves.easeOutCubic);
  }
}
