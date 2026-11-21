import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/providers/notes_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sort defaults to recently updated', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(noteSortProvider), NoteSort.updated);
  });

  test('set() persists the sort and load() restores it', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(noteSortProvider.notifier).set(NoteSort.titleAsc);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('strata_note_sort'), NoteSort.titleAsc.index);

    // A fresh container stands in for the next app launch.
    final relaunched = ProviderContainer();
    addTearDown(relaunched.dispose);
    await relaunched.read(noteSortProvider.notifier).load();
    expect(relaunched.read(noteSortProvider), NoteSort.titleAsc);
  });

  test('load() clamps an unknown stored index into range', () async {
    SharedPreferences.setMockInitialValues({'strata_note_sort': 99});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(noteSortProvider.notifier).load();
    expect(
      container.read(noteSortProvider),
      NoteSort.values[NoteSort.values.length - 1],
    );
  });
}
