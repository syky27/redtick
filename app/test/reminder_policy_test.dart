import 'package:flutter_test/flutter_test.dart';
import 'package:redtick/src/state/reminder_settings.dart';

/// A Monday 10:00 reference instant (DateTime.weekday == 1).
final _mon10 = DateTime(2024, 1, 1, 10, 0); // 2024-01-01 is a Monday.

void main() {
  group('shouldRemind gating', () {
    test('fires when enabled, not running, interval elapsed', () {
      expect(
        shouldRemind(
          now: _mon10,
          lastReminder: _mon10.subtract(const Duration(minutes: 11)),
          running: false,
          s: const ReminderSettings(minutes: 10),
        ),
        isTrue,
      );
    });

    test('does not fire when disabled', () {
      expect(
        shouldRemind(
          now: _mon10,
          lastReminder: null,
          running: false,
          s: const ReminderSettings(enabled: false),
        ),
        isFalse,
      );
    });

    test('does not fire while a timer is running', () {
      expect(
        shouldRemind(
          now: _mon10,
          lastReminder: null,
          running: true,
          s: const ReminderSettings(),
        ),
        isFalse,
      );
    });

    test('throttles within the interval', () {
      expect(
        shouldRemind(
          now: _mon10,
          lastReminder: _mon10.subtract(const Duration(minutes: 5)),
          running: false,
          s: const ReminderSettings(minutes: 10),
        ),
        isFalse,
      );
    });

    test('does not fire on a disabled weekday', () {
      expect(
        shouldRemind(
          now: _mon10, // Monday
          lastReminder: null,
          running: false,
          s: const ReminderSettings(weekdays: {2, 3, 4, 5, 6, 7}), // no Monday
        ),
        isFalse,
      );
    });

    test('respects the active-hours window', () {
      // Window 12:00–18:00; now is 10:00 → before the window.
      expect(
        shouldRemind(
          now: _mon10,
          lastReminder: null,
          running: false,
          s: const ReminderSettings(startHHmm: '12:00', endHHmm: '18:00'),
        ),
        isFalse,
      );
      // Inside the window.
      expect(
        shouldRemind(
          now: DateTime(2024, 1, 1, 13, 0),
          lastReminder: null,
          running: false,
          s: const ReminderSettings(startHHmm: '12:00', endHHmm: '18:00'),
        ),
        isTrue,
      );
      // After the window.
      expect(
        shouldRemind(
          now: DateTime(2024, 1, 1, 19, 0),
          lastReminder: null,
          running: false,
          s: const ReminderSettings(startHHmm: '12:00', endHHmm: '18:00'),
        ),
        isFalse,
      );
    });

    test('null lastReminder is eligible (no throttle anchor yet)', () {
      expect(
        shouldRemind(
          now: _mon10,
          lastReminder: null,
          running: false,
          s: const ReminderSettings(),
        ),
        isTrue,
      );
    });
  });

  group('helpers', () {
    test('minutesOfDay parses and rejects', () {
      expect(minutesOfDay('09:30'), 9 * 60 + 30);
      expect(minutesOfDay('0:05'), 5);
      expect(minutesOfDay(null), isNull);
      expect(minutesOfDay(''), isNull);
      expect(minutesOfDay('24:00'), isNull);
      expect(minutesOfDay('12:60'), isNull);
      expect(minutesOfDay('nonsense'), isNull);
    });

    test('weekday bitmask round-trips', () {
      const all = {1, 2, 3, 4, 5, 6, 7};
      expect(ReminderSettings.weekdaysToString(all), '1111111');
      expect(ReminderSettings.parseWeekdays('1111111'), all);
      // Weekdays only (Mon–Fri).
      expect(ReminderSettings.weekdaysToString({1, 2, 3, 4, 5}), '1111100');
      expect(ReminderSettings.parseWeekdays('1111100'), {1, 2, 3, 4, 5});
      // Malformed → default all-on.
      expect(ReminderSettings.parseWeekdays('xyz'), all);
      expect(ReminderSettings.parseWeekdays(null), all);
    });

    test('clampMinutes enforces the 1..999 bounds', () {
      expect(ReminderSettings.clampMinutes(0), 1);
      expect(ReminderSettings.clampMinutes(-5), 1);
      expect(ReminderSettings.clampMinutes(10), 10);
      expect(ReminderSettings.clampMinutes(5000), 999);
    });
  });
}
