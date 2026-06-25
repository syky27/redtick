import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/reminder_settings.dart';

/// Wraps the app shell and, while **no** timer is running, periodically nags the
/// user to track their time — an OS notification (when available) plus an in-app
/// banner. Mirrors the Qt app's "remind me to track time" feature. The gating
/// (interval, weekdays, active-hours window) lives in [shouldRemind]; this
/// widget just drives the clock and surfaces the notice. Design §3.9 / screen
/// 10 ("IDLE & REMINDERS").
class ReminderWatcher extends ConsumerStatefulWidget {
  const ReminderWatcher({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ReminderWatcher> createState() => _ReminderWatcherState();
}

class _ReminderWatcherState extends ConsumerState<ReminderWatcher> {
  Timer? _timer;

  /// Anchor for the "every N minutes" throttle. Initialised to now so the first
  /// reminder is a full interval away, and re-anchored whenever a timer runs so
  /// the countdown starts fresh once tracking stops.
  DateTime? _lastReminder;

  @override
  void initState() {
    super.initState();
    _lastReminder = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final settings = ref.read(reminderSettingsProvider);
    final running = ref.read(timerStateProvider).asData?.value;
    final isRunning = running != null && running.isRunning;
    final now = DateTime.now();

    if (isRunning) {
      _lastReminder = now; // re-anchor: count the gap from when tracking stops
      return;
    }
    if (!shouldRemind(
      now: now,
      lastReminder: _lastReminder,
      running: false,
      s: settings,
    )) {
      return;
    }

    _lastReminder = now;
    const title = 'Redtick';
    const body = 'No timer running — track your time?';
    ref.read(notificationPresenterProvider).show(title, body);
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(const SnackBar(content: Text('$title — $body')));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
