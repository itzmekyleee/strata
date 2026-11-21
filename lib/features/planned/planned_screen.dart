import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/strata_palette.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/skeleton_card.dart';
import '../../data/models/note.dart';
import '../../providers/notes_providers.dart';
import '../home/widgets/note_tile.dart';

/// Upcoming reminders: every active note with a due date, grouped by how
/// soon it is due.
class PlannedScreen extends ConsumerWidget {
  const PlannedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plannedAsync = ref.watch(plannedNotesProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text(
          'Planned',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: plannedAsync.when(
          loading: () => const NoteListSkeleton(),
          error: (e, _) => Center(
            child: Text('Something went wrong\n$e', textAlign: TextAlign.center),
          ),
          data: (notes) => _PlannedList(notes: notes),
        ),
      ),
    );
  }
}

class _PlannedList extends StatelessWidget {
  const _PlannedList({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 46,
              color: StrataPalette.accent.withValues(alpha: .8),
            ),
            const SizedBox(height: 16),
            Text('Nothing scheduled', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Reminders you set on notes show up here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: StrataPalette.onSurfaceMuted,
              ),
            ),
          ],
        ).entrance(index: 0),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <(String, Color, List<Note>)>[];
    void add(String label, Color color, bool Function(DateTime due) match) {
      final hits = [
        for (final n in notes)
          if (match(DateTime(
            n.dueDate!.year,
            n.dueDate!.month,
            n.dueDate!.day,
          )))
            n,
      ];
      if (hits.isNotEmpty) groups.add((label, color, hits));
    }

    add('Overdue', StrataPalette.coral, (d) => d.isBefore(today));
    add('Today', StrataPalette.amber, (d) => d.isAtSameMomentAs(today));
    add(
      'Upcoming',
      StrataPalette.accent,
      (d) => d.isAfter(today) && d.isBefore(today.add(const Duration(days: 7))),
    );

    final upcomingEnd = today.add(const Duration(days: 7));
    final later = [
      for (final n in notes)
        if (!DateTime(n.dueDate!.year, n.dueDate!.month, n.dueDate!.day)
            .isBefore(upcomingEnd))
          n,
    ];
    if (later.isNotEmpty) {
      groups.add(('Later', StrataPalette.onSurfaceMuted, later));
    }

    var index = 0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 96),
          itemCount: groups.fold<int>(0, (n, g) => n + g.$3.length + 1),
          itemBuilder: (context, i) {
            // Walk the flattened (header, tile…) sequence lazily.
            var cursor = i;
            for (final (label, color, items) in groups) {
              if (cursor == 0) return _SectionHeader(label: label, color: color);
              cursor--;
              if (cursor < items.length) {
                return NoteTile(note: items[cursor], index: index++);
              }
              cursor -= items.length;
            }
            throw StateError('index out of range');
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .9,
              color: StrataPalette.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}
