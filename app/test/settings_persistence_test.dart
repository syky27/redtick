import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redtick/src/state/idle_settings.dart';
import 'package:redtick/src/state/reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Let the notifier's async `_load()` (which awaits SharedPreferences) settle.
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IdleSettings persistence', () {
    test('defaults when prefs empty (5 min, on)', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final s = c.read(idleSettingsProvider);
      expect(s.minutes, 5);
      expect(s.enabled, true);
    });

    test('set + clamp persists', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(idleSettingsProvider.notifier).setMinutes(15);
      expect(c.read(idleSettingsProvider).minutes, 15);
      await c.read(idleSettingsProvider.notifier).setMinutes(0);
      expect(c.read(idleSettingsProvider).minutes, 1); // floor
      await c.read(idleSettingsProvider.notifier).setEnabled(false);
      expect(c.read(idleSettingsProvider).enabled, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('idle_minutes'), 1);
      expect(prefs.getBool('idle_detection_enabled'), false);
    });

    test('loads persisted values into a fresh container', () async {
      SharedPreferences.setMockInitialValues({
        'idle_minutes': 42,
        'idle_detection_enabled': false,
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(idleSettingsProvider); // trigger build()/_load()
      await _settle();
      final s = c.read(idleSettingsProvider);
      expect(s.minutes, 42);
      expect(s.enabled, false);
    });
  });

  group('ReminderSettings persistence', () {
    test('defaults when prefs empty (10 min, on, all days, no window)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final s = c.read(reminderSettingsProvider);
      expect(s.minutes, 10);
      expect(s.enabled, true);
      expect(s.weekdays, {1, 2, 3, 4, 5, 6, 7});
      expect(s.startHHmm, isNull);
      expect(s.endHHmm, isNull);
    });

    test('toggle weekday, set window, then clear', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(reminderSettingsProvider.notifier);

      await n.toggleWeekday(6, false); // drop Saturday
      await n.toggleWeekday(7, false); // drop Sunday
      expect(c.read(reminderSettingsProvider).weekdays, {1, 2, 3, 4, 5});

      await n.setStart('09:00');
      await n.setEnd('17:30');
      expect(c.read(reminderSettingsProvider).startHHmm, '09:00');
      expect(c.read(reminderSettingsProvider).endHHmm, '17:30');

      await n.setStart(null); // clear lower bound
      expect(c.read(reminderSettingsProvider).startHHmm, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reminder_weekdays'), '1111100');
      expect(prefs.getString('reminder_start'), '');
      expect(prefs.getString('reminder_end'), '17:30');
    });

    test('loads persisted values into a fresh container', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_enabled': false,
        'reminder_minutes': 25,
        'reminder_weekdays': '1010101',
        'reminder_start': '08:00',
        'reminder_end': '', // empty → no upper bound
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(reminderSettingsProvider);
      await _settle();
      final s = c.read(reminderSettingsProvider);
      expect(s.enabled, false);
      expect(s.minutes, 25);
      expect(s.weekdays, {1, 3, 5, 7});
      expect(s.startHHmm, '08:00');
      expect(s.endHHmm, isNull);
    });
  });
}
