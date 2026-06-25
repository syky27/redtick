import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Remind me to track time" settings: a nag notification that fires when the
/// app is running but **no** timer is active. Full parity with the Qt app's
/// `reminder` / `reminder_minutes` / per-weekday `remind_*` / active-hours
/// window (`remind_starts`/`remind_ends`). Defaults: on, every 10 min, all
/// weekdays, no time window. Persisted with shared_preferences.
class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.minutes = 10,
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.startHHmm,
    this.endHHmm,
  });

  final bool enabled;
  final int minutes;

  /// Days the reminder may fire on, using Dart's `DateTime.weekday`
  /// (Mon = 1 … Sun = 7).
  final Set<int> weekdays;

  /// Active-hours window as "HH:mm" strings; null/empty = no bound.
  final String? startHHmm;
  final String? endHHmm;

  ReminderSettings copyWith({
    bool? enabled,
    int? minutes,
    Set<int>? weekdays,
    String? startHHmm,
    String? endHHmm,
    bool clearStart = false,
    bool clearEnd = false,
  }) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        minutes: minutes ?? this.minutes,
        weekdays: weekdays ?? this.weekdays,
        startHHmm: clearStart ? null : (startHHmm ?? this.startHHmm),
        endHHmm: clearEnd ? null : (endHHmm ?? this.endHHmm),
      );

  /// Qt enforces a 1-minute floor; the UI uses a 3-digit field (≤ 999).
  static int clampMinutes(int v) => v < 1 ? 1 : (v > 999 ? 999 : v);

  /// 7-char bitmask, index 0 = Monday … index 6 = Sunday.
  static Set<int> parseWeekdays(String? s) {
    if (s == null || s.length != 7) return const {1, 2, 3, 4, 5, 6, 7};
    final out = <int>{};
    for (var i = 0; i < 7; i++) {
      if (s[i] == '1') out.add(i + 1);
    }
    return out;
  }

  static String weekdaysToString(Set<int> w) {
    final b = StringBuffer();
    for (var i = 1; i <= 7; i++) {
      b.write(w.contains(i) ? '1' : '0');
    }
    return b.toString();
  }
}

class ReminderSettingsNotifier extends Notifier<ReminderSettings> {
  static const _kEnabled = 'reminder_enabled';
  static const _kMinutes = 'reminder_minutes';
  static const _kWeekdays = 'reminder_weekdays';
  static const _kStart = 'reminder_start';
  static const _kEnd = 'reminder_end';

  @override
  ReminderSettings build() {
    _load();
    return const ReminderSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final start = prefs.getString(_kStart);
    final end = prefs.getString(_kEnd);
    state = ReminderSettings(
      enabled: prefs.getBool(_kEnabled) ?? true,
      minutes: ReminderSettings.clampMinutes(prefs.getInt(_kMinutes) ?? 10),
      weekdays: ReminderSettings.parseWeekdays(prefs.getString(_kWeekdays)),
      startHHmm: (start == null || start.isEmpty) ? null : start,
      endHHmm: (end == null || end.isEmpty) ? null : end,
    );
  }

  Future<void> setEnabled(bool v) async {
    state = state.copyWith(enabled: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, v);
  }

  Future<void> setMinutes(int v) async {
    final m = ReminderSettings.clampMinutes(v);
    state = state.copyWith(minutes: m);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMinutes, m);
  }

  Future<void> toggleWeekday(int weekday, bool on) async {
    final next = Set<int>.from(state.weekdays);
    if (on) {
      next.add(weekday);
    } else {
      next.remove(weekday);
    }
    state = state.copyWith(weekdays: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWeekdays, ReminderSettings.weekdaysToString(next));
  }

  /// Pass null/empty to clear the bound (no window edge).
  Future<void> setStart(String? hhmm) async {
    final v = (hhmm == null || hhmm.isEmpty) ? null : hhmm;
    state = state.copyWith(startHHmm: v, clearStart: v == null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStart, v ?? '');
  }

  Future<void> setEnd(String? hhmm) async {
    final v = (hhmm == null || hhmm.isEmpty) ? null : hhmm;
    state = state.copyWith(endHHmm: v, clearEnd: v == null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEnd, v ?? '');
  }
}

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
        ReminderSettingsNotifier.new);

/// Pure gating for the "running but not tracking" reminder, ported from the Qt
/// app's `Context::displayReminder`. Returns true when a reminder should fire
/// *now*. Kept free of Flutter/timer deps so it is unit-testable.
bool shouldRemind({
  required DateTime now,
  DateTime? lastReminder,
  required bool running,
  required ReminderSettings s,
}) {
  if (!s.enabled) return false;
  if (running) return false; // only nag when no timer is active
  // Throttle: at least `minutes` since the previous reminder.
  if (lastReminder != null &&
      now.difference(lastReminder) < Duration(minutes: s.minutes)) {
    return false;
  }
  // Weekday must be enabled (DateTime.weekday: Mon = 1 … Sun = 7).
  if (!s.weekdays.contains(now.weekday)) return false;
  // Active-hours window (inclusive of both edges, matching the Qt comparison).
  final start = minutesOfDay(s.startHHmm);
  final end = minutesOfDay(s.endHHmm);
  final cur = now.hour * 60 + now.minute;
  if (start != null && cur < start) return false;
  if (end != null && cur > end) return false;
  return true;
}

/// Parses "HH:mm" to minutes-since-midnight, or null if absent/invalid.
int? minutesOfDay(String? hhmm) {
  if (hhmm == null || hhmm.isEmpty) return null;
  final m = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*$').firstMatch(hhmm);
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}
