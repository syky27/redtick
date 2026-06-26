import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:redtick/src/state/reminder_notice.dart';
import 'package:redtick/src/ui/theme.dart';
import 'package:redtick/src/ui/widgets/reminder_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('reminder banner shows on show() and hides on clear()',
      (tester) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: RedtickTheme.light(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const ReminderBanner();
              },
            ),
          ),
        ),
      ),
    );

    const msg = 'No timer running — track your time?';
    expect(find.text(msg), findsNothing);

    capturedRef.read(reminderNoticeProvider.notifier).show(msg);
    await tester.pumpAndSettle();
    expect(find.text(msg), findsOneWidget);

    capturedRef.read(reminderNoticeProvider.notifier).clear();
    await tester.pumpAndSettle();
    expect(find.text(msg), findsNothing);
  });
}
