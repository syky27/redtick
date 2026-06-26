import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:redtick/src/models/time_entry.dart';
import 'package:redtick/src/ui/theme.dart';
import 'package:redtick/src/ui/widgets/entry_bits.dart';

// A running-card entry with both an issue ref and a long project name — the
// shape that triggered `RenderFlex overflowed by 0.03 px` in EntrySubline.
TimeEntry _entry() => const TimeEntry(
      id: 1,
      guid: 'g',
      description: 'Odebrat vodoznak',
      durationInSeconds: 1,
      duration: '0:00:01',
      projectLabel: 'documentflow.budzakbuilding.cz',
      taskLabel: '#23409: Odebrat vodoznak',
      clientLabel: '',
      color: '#3b82f6',
      tags: '',
      billable: false,
      started: 0,
      ended: 0,
      startTimeString: '',
      endTimeString: '',
      isHeader: false,
      dateHeader: '',
      dateDuration: '',
      unsynced: false,
      error: '',
      activityId: 0,
    );

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('IssueChip subline never overflows at tight widths',
      (tester) async {
    // Includes 49.8 — the exact constraint from the reported overflow.
    for (final w in <double>[40, 49.8, 60, 90, 140]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: RedtickTheme.light(),
            home: Scaffold(
              body: Center(
                child: SizedBox(width: w, child: IssueChip(entry: _entry())),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull,
          reason: 'EntrySubline overflowed at width $w');
    }
  });
}
