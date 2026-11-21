import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:strata/core/utils/due_status.dart';

DateTime _at(int year, int month, int day, [int h = 0, int m = 0]) =>
    DateTime(year, month, day, h, m);

void main() {
  final now = _at(2026, 8, 23, 12, 0); // Sun Aug 23 2026, noon

  test('null due date classifies to null', () {
    expect(DueStatusX.classify(null, now: now), isNull);
    expect(DueStatusX.isOverdue(null, now: now), isFalse);
  });

  test('future days are upcoming', () {
    expect(
      DueStatusX.classify(_at(2026, 8, 24, 9), now: now),
      DueStatus.upcoming,
    );
    expect(DueStatusX.isOverdue(_at(2026, 8, 24, 9), now: now), isFalse);
  });

  test('later today is today, not overdue', () {
    expect(
      DueStatusX.classify(_at(2026, 8, 23, 18), now: now),
      DueStatus.today,
    );
    expect(DueStatusX.isOverdue(_at(2026, 8, 23, 18), now: now), isFalse);
  });

  test('earlier today is still today (grace until midnight)', () {
    expect(DueStatusX.classify(_at(2026, 8, 23, 9), now: now), DueStatus.today);
    expect(DueStatusX.isOverdue(_at(2026, 8, 23, 9), now: now), isFalse);
  });

  test('past days are overdue', () {
    expect(
      DueStatusX.classify(_at(2026, 8, 22, 23, 59), now: now),
      DueStatus.overdue,
    );
    expect(DueStatusX.classify(_at(2026, 1, 1), now: now), DueStatus.overdue);
    expect(DueStatusX.isOverdue(_at(2026, 8, 22), now: now), isTrue);
  });

  test('exact same instant as now counts as today', () {
    expect(DueStatusX.classify(now, now: now), DueStatus.today);
  });

  test('labels: today and tomorrow include time', () {
    expect(
      DueStatusX.labelFor(_at(2026, 8, 23, 14, 5), now: now),
      'Today ${DateFormat.Hm().format(_at(2026, 8, 23, 14, 5))}',
    );
    expect(
      DueStatusX.labelFor(_at(2026, 8, 24, 7, 30), now: now),
      'Tomorrow ${DateFormat.Hm().format(_at(2026, 8, 24, 7, 30))}',
    );
  });

  test('label for other days includes weekday date', () {
    final label = DueStatusX.labelFor(_at(2026, 8, 25, 8, 0), now: now);
    expect(label, contains(DateFormat.MMMEd().format(_at(2026, 8, 25))));
    expect(label, endsWith(DateFormat.Hm().format(_at(2026, 8, 25, 8))));
  });
}
