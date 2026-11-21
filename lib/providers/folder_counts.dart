import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';

/// A map of folderId → note count (non-trashed, non-template).
/// The key `null` represents root-level (unfiled) notes.
final folderNoteCountProvider = StreamProvider<Map<int?, int>>((ref) {
  return ref.watch(notesRepositoryProvider).watchAll().map((notes) {
    final counts = <int?, int>{};
    for (final note in notes) {
      counts[note.folderId] = (counts[note.folderId] ?? 0) + 1;
    }
    return counts;
  });
});
