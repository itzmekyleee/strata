import 'package:flutter/services.dart'
    show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/note.dart';

/// Schedules local "note is due" notifications.
///
/// One notification per note; the notification id is derived from the note
/// id so re-scheduling replaces cleanly. Exact alarms are preferred with an
/// automatic fallback to inexact scheduling when the OS withholds the
/// SCHEDULE_EXACT_ALARM permission (Android 14+).
class ReminderService {
  ReminderService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  bool _permissionsAsked = false;

  static const _channelId = 'strata_reminders';
  static const _channelName = 'Note reminders';
  static const _channelDescription = 'Reminds you when a note is due';

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC rather than failing hard.
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }
    try {
      // Must be a drawable resource, not mipmap: the plugin resolves the
      // icon via getIdentifier(name, "drawable", ...) only.
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_launcher_foreground'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ));
    } catch (_) {
      // Notifications are optional; never block app startup on them.
      return;
    }
    _ready = true;
  }

  /// OS permission prompts. Only invoked when the user actively sets a
  /// reminder, never during passive start-up resyncs.
  Future<void> ensurePermissions() async {
    if (_permissionsAsked) return;
    _permissionsAsked = true;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  int idFor(int noteId) => noteId % 0x7FFFFFFF;

  /// Cancels any existing notification for [note], then schedules one at
  /// its due date if that date is still in the future.
  Future<void> scheduleFor(Note note, {bool askPermissions = false}) async {
    await init();
    await cancel(note.id);
    final due = note.dueDate;
    if (due == null || !due.isAfter(DateTime.now())) return;
    if (askPermissions) await ensurePermissions();

    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    final title = note.title.trim().isEmpty ? 'Untitled' : note.title.trim();
    final scheduled = tz.TZDateTime.from(due, tz.local);

    for (final mode in [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _plugin.zonedSchedule(
          id: idFor(note.id),
          title: title,
          body: 'This note is due now.',
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: mode,
          payload: 'note:${note.id}',
        );
        return;
      } on PlatformException {
        // Exact alarms unavailable — retry with the next mode.
      }
    }
  }

  Future<void> cancel(int noteId) async {
    await init();
    await _plugin.cancel(id: idFor(noteId));
  }

  /// Heals drift after restarts, restores, or missed boot reschedules:
  /// drops everything scheduled and re-arms only currently valid reminders.
  /// Never triggers OS permission prompts.
  Future<void> resyncAll(Iterable<Note> notes) async {
    await init();
    await _plugin.cancelAll();
    for (final n in notes) {
      await scheduleFor(n);
    }
  }
}
