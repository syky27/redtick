import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drives the persistent "track your time" reminder banner. Set visible by
/// [ReminderWatcher] when a reminder is due and cleared the instant any timer
/// starts (see the `runningEntries` listener in `app.dart`). Unlike the
/// release-watch dismissal this is session-only state — the banner is a live
/// reflection of "no timer is running", not a one-off dismissible notice, so it
/// is not persisted to SharedPreferences.
class ReminderNoticeState {
  const ReminderNoticeState({this.visible = false, this.body = ''});

  final bool visible;
  final String body;
}

class ReminderNoticeNotifier extends Notifier<ReminderNoticeState> {
  @override
  ReminderNoticeState build() => const ReminderNoticeState();

  /// Show the banner (idempotent while already visible with the same body).
  void show(String body) {
    if (state.visible && state.body == body) return;
    state = ReminderNoticeState(visible: true, body: body);
  }

  /// Hide the banner — called when a timer starts.
  void clear() {
    if (state.visible) state = const ReminderNoticeState();
  }
}

final reminderNoticeProvider =
    NotifierProvider<ReminderNoticeNotifier, ReminderNoticeState>(
        ReminderNoticeNotifier.new);
