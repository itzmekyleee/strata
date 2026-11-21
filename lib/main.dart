import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/strata_app.dart';
import 'app/theme/strata_palette.dart';
import 'app/theme/theme_variant.dart';
import 'core/widgets/splash.dart';
import 'core/widgets/welcome_sheet.dart';
import 'data/database.dart';
import 'data/repositories/attachments_repository.dart';
import 'data/repositories/notes_repository.dart';
import 'data/repositories/sync_repository.dart';
import 'data/services/attachment_storage.dart';
import 'data/services/note_actions.dart';
import 'data/services/reminder_service.dart';
import 'data/services/sync/sync_engine.dart';
import 'providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show branded splash immediately while heavy init runs.
  runApp(const Splash());

  final db = await AppDatabase.open();
  final storage = AttachmentStorage();
  await storage.init();

  // Give pre-sync data its sync identity before anything else runs.
  await SyncRepository(db.isar).ensureSyncIds();

  final reminders = ReminderService(FlutterLocalNotificationsPlugin());
  await reminders.init();
  // Heal reminder drift after restarts: re-arm only still-valid reminders.
  final notesRepo = NotesRepository(db.isar);
  await reminders.resyncAll(await notesRepo.upcomingReminders(DateTime.now()));

  // LAN sync: load config; start server/discovery only when enabled.
  final syncEngine = SyncEngine(isar: db.isar, storage: storage);
  await syncEngine.load();

  // Load persisted theme variant and apply its colors.
  final prefs = await SharedPreferences.getInstance();
  final variantIndex = prefs.getInt('strata_theme_variant') ?? 0;
  final initialVariant =
      ThemeVariant.values[variantIndex.clamp(0, ThemeVariant.values.length - 1)];
  StrataPalette.applyVariant(initialVariant);
  // After each exchange, cancel reminders of deleted/trashed notes and
  // re-arm the rest from local state.
  syncEngine.onExchangeApplied = (result) async {
    for (final id in result.cancelledNoteIds) {
      await reminders.cancel(id);
    }
    await reminders.resyncAll(
      await notesRepo.upcomingReminders(DateTime.now()),
    );
  };
  unawaited(syncEngine.start());
  // Tombstones older than 30 days have long since reached every peer.
  unawaited(
    SyncRepository(
      db.isar,
    ).pruneTombstones(DateTime.now().subtract(const Duration(days: 30))),
  );

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        storageProvider.overrideWithValue(storage),
        remindersProvider.overrideWithValue(reminders),
        syncEngineProvider.overrideWithValue(syncEngine),
      ],
      child: const StrataApp(),
    ),
  );

  // First-run welcome sheet (shown after the main app is mounted).
  if (await isFirstRun()) {
    // Small delay so the first frame renders before the modal covers it.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    // Use a global navigator key if available; otherwise skip gracefully.
  }

  Future<void>.delayed(const Duration(seconds: 2), () async {
    final actions = NoteActions(
      NotesRepository(db.isar),
      AttachmentsRepository(db.isar, storage),
      storage,
      reminders,
    );
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    await actions.purgeOlderThan(cutoff);
  });
}
