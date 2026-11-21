import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/strata_palette.dart';
import '../../../providers/notes_providers.dart';
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
  });

  final FocusNode focusNode;
  final VoidCallback onClose;

  @override
  ConsumerState<InlineSearchPanel> createState() => _InlineSearchPanelState();
}

class _InlineSearchPanelState extends ConsumerState<InlineSearchPanel> {
  late final TextEditingController _ctrl;

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

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final theme = Theme.of(context);

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
        Expanded(
          child: results.when(
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
              return ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 40),
                itemCount: list.length,
                itemBuilder: (context, i) => NoteTile(
                  note: list[i],
                  index: i,
                  highlightQuery: query,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
