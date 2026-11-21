import 'package:intl/intl.dart';

enum DueStatus { overdue, today, upcoming }

/// Pure helpers for classifying and labeling a note's due date.
abstract final class DueStatusX {
  /// Null when there is no due date; otherwise how it relates to [now].
  static DueStatus? classify(DateTime? dueDate, {DateTime? now}) {
    if (dueDate == null) return null;
    final n = now ?? DateTime.now();
    final sameDay = _sameDay(dueDate, n);
    if (!dueDate.isBefore(n)) {
      return sameDay ? DueStatus.today : DueStatus.upcoming;
    }
    // Already passed: still counts as 'today' until the day ends.
    return sameDay ? DueStatus.today : DueStatus.overdue;
  }

  static bool isOverdue(DateTime? dueDate, {DateTime? now}) =>
      classify(dueDate, now: now) == DueStatus.overdue;

  static String labelFor(DateTime due, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final time = DateFormat.Hm().format(due);
    if (_sameDay(due, n)) return 'Today $time';
    final tomorrow = n.add(const Duration(days: 1));
    if (_sameDay(due, tomorrow)) return 'Tomorrow $time';
    return '${DateFormat.MMMEd().format(due)} $time';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
