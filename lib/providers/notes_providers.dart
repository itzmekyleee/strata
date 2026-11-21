import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/note.dart';
import '../data/models/note_folder.dart';
import '../data/models/tag.dart';
import 'core_providers.dart';

final foldersStreamProvider = StreamProvider.autoDispose<List<NoteFolder>>((
  ref,
) {
  return ref.watch(foldersRepositoryProvider).watchAll();
});

final notesInFolderProvider = StreamProvider.autoDispose
    .family<List<Note>, int?>((ref, folderId) {
      final sort = ref.watch(noteSortProvider);
      return ref
          .watch(notesRepositoryProvider)
          .watchNotes(
            folderId: folderId,
            sort: sort,
          );
    });

enum NoteSort { updated, dueDate, titleAsc }

const _sortPrefKey = 'strata_note_sort';

class NoteSortSetting extends Notifier<NoteSort> {
  @override
  NoteSort build() => NoteSort.updated;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_sortPrefKey) ?? 0;
    state = NoteSort.values[index.clamp(0, NoteSort.values.length - 1)];
  }

  Future<void> set(NoteSort sort) async {
    state = sort;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sortPrefKey, sort.index);
  }
}

final noteSortProvider = NotifierProvider<NoteSortSetting, NoteSort>(
  NoteSortSetting.new,
);

final pinnedNotesProvider = StreamProvider.autoDispose<List<Note>>((ref) {
  return ref.watch(notesRepositoryProvider).watchPinned();
});

final trashStreamProvider = StreamProvider.autoDispose<List<Note>>((ref) {
  return ref.watch(notesRepositoryProvider).watchTrash();
});

final templatesStreamProvider = StreamProvider.autoDispose<List<Note>>((ref) {
  return ref.watch(notesRepositoryProvider).watchTemplates();
});

/// Every active note with a reminder, soonest first — feeds the Planned tab.
final plannedNotesProvider = StreamProvider.autoDispose<List<Note>>((ref) {
  return ref
      .watch(notesRepositoryProvider)
      .watchNotes()
      .map(
        (notes) =>
            [...notes.where((n) => n.dueDate != null)]
              ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!)),
      );
});

final tagsStreamProvider = StreamProvider.autoDispose<List<Tag>>((ref) {
  return ref.watch(tagsRepositoryProvider).watchAll();
});

class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(
  SearchQuery.new,
);

final searchResultsProvider = FutureProvider.autoDispose<List<Note>>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return const [];
  await Future<void>.delayed(const Duration(milliseconds: 220));
  return ref.watch(notesRepositoryProvider).search(query);
});

final noteByIdProvider = StreamProvider.autoDispose.family<Note?, int>((
  ref,
  id,
) {
  return ref.watch(notesRepositoryProvider).watchById(id);
});

final backlinksProvider = StreamProvider.autoDispose.family<List<Note>, int>((
  ref,
  noteId,
) {
  return ref.watch(notesRepositoryProvider).watchBacklinks(noteId);
});
