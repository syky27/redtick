import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redtick/src/models/time_entry.dart';
import 'package:redtick/src/platform/notifications.dart';
import 'package:redtick/src/state/providers.dart';
import 'package:redtick/src/state/reminder_notice.dart';
import 'package:redtick/src/ui/widgets/reminder_watcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A no-op presenter so the watcher doesn't reach the real OS plugin in tests.
class _NoopPresenter implements NotificationPresenter {
  @override
  Future<void> init() async {}
  @override
  Future<bool> show(String title, String body) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('does not nag until idle is sustained across two ticks',
      (tester) async {
    var clock = DateTime(2024, 1, 1, 10, 0, 0); // Monday 10:00

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timerStateProvider
              .overrideWith((ref) => Stream<TimeEntry?>.value(null)),
          notificationPresenterProvider.overrideWithValue(_NoopPresenter()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ReminderWatcher(
              clock: () => clock,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(); // settle the timerState stream to data(null)

    final container = ProviderScope.containerOf(
        tester.element(find.byType(ReminderWatcher)));

    // Satisfy the 10-minute throttle, so the ONLY thing gating the first tick is
    // the sustained-idle guard.
    clock = clock.add(const Duration(minutes: 11));

    // First 30s tick → idleTicks = 1 (< threshold): no notice.
    await tester.pump(const Duration(seconds: 30));
    expect(container.read(reminderNoticeProvider).visible, isFalse);

    // Second tick → idleTicks = 2: the banner is shown.
    await tester.pump(const Duration(seconds: 30));
    expect(container.read(reminderNoticeProvider).visible, isTrue);
  });
}
