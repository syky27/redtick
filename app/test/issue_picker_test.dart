@TestOn('vm')
library;

// The issue picker's desktop affordances:
//  - a typed query that finds nothing in a narrow scope (My issues / Assigned)
//    auto-broadens to "All visible" so the user still lands on the issue
//  - ↑/↓ move a highlight and Enter starts the timer on the highlighted issue
//
// Keyboard nav is desktop-only; `flutter test` runs on a desktop host, so the
// inline Platform.is{MacOS,Windows,Linux} check is true here and the keyboard
// path is exercised for real.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redtick/src/data/redmine_service.dart';
import 'package:redtick/src/state/providers.dart';
import 'package:redtick/src/ui/theme.dart';
import 'package:redtick/src/ui/widgets/issue_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Redmine backend whose `/issues.json` answer depends on the scope:
///  - narrow scope (`assigned_to_id=me`) + a text/id filter → **empty**
///  - narrow scope, no filter → the two "my" issues (Alpha, Beta)
///  - broad scope (no `assigned_to_id`) + filter → the escalation-only issue
http.Client pickerBackend() {
  http.Response j(Object o, [int s = 200]) => http.Response(jsonEncode(o), s,
      headers: {'content-type': 'application/json'});
  Map<String, dynamic> issue(int id, String subject) => {
        'id': id,
        'subject': subject,
        'project': {'id': 75, 'name': 'SUMA'},
        'status': {'name': 'New', 'is_closed': false},
      };
  return MockClient((req) async {
    final p = req.url.path;
    final qp = req.url.queryParameters;
    if (req.method == 'GET') {
      if (p.endsWith('/users/current.json')) {
        return j({
          'user': {'id': 9, 'mail': 'me@x.cz', 'firstname': 'Me', 'lastname': ''}
        });
      }
      if (p.endsWith('/projects.json')) {
        return j({
          'projects': [
            {'id': 75, 'name': 'SUMA', 'status': 1}
          ],
          'total_count': 1
        });
      }
      if (p.endsWith('/time_entry_activities.json')) {
        return j({
          'time_entry_activities': [
            {'id': 6, 'name': 'Development', 'is_default': true, 'active': true}
          ]
        });
      }
      if (p.endsWith('/custom_fields.json')) {
        return j({
          'custom_fields': [
            {'id': 12, 'name': 'toggl_start', 'customized_type': 'time_entry'},
            {'id': 14, 'name': 'toggl_stop', 'customized_type': 'time_entry'},
            {'id': 13, 'name': 'toggl_guid', 'customized_type': 'time_entry'},
          ]
        });
      }
      if (p.endsWith('/time_entries.json')) {
        return j({'time_entries': const [], 'total_count': 0});
      }
      if (p.endsWith('/issues.json')) {
        final narrow = qp['assigned_to_id'] == 'me';
        final filtered =
            qp.containsKey('subject') || qp.containsKey('issue_id');
        final List<Map<String, dynamic>> list;
        if (narrow && filtered) {
          list = const []; // My issues / Assigned: the query matches nothing
        } else if (narrow) {
          list = [issue(100, 'Alpha issue'), issue(200, 'Beta issue')];
        } else if (filtered) {
          list = [issue(555, 'Zeta only in all')]; // escalation target
        } else {
          list = [
            issue(100, 'Alpha issue'),
            issue(200, 'Beta issue'),
            issue(555, 'Zeta only in all'),
          ];
        }
        return j({'issues': list, 'total_count': list.length});
      }
    }
    return http.Response('not found', 404);
  });
}

/// Log a service in against [client] (keychain writes fall back to prefs in the
/// test VM). Runs under real async — login touches platform channels.
Future<RedmineService> loggedIn(WidgetTester tester, http.Client client) async {
  return (await tester.runAsync(() async {
    final svc = await RedmineService.create(httpClient: client);
    final ready = svc.loginState.firstWhere((e) => e.loggedIn);
    svc.setBaseUrl('https://x');
    svc.login('', 'key');
    await ready.timeout(const Duration(seconds: 5));
    return svc;
  }))!;
}

/// Pump a handful of frames so the (microtask-based) MockClient futures resolve
/// and the dialog rebuilds. Avoids pumpAndSettle, which would hang on the
/// service's 30s poll timer.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Widget host(RedmineService svc, void Function(IssueResult?) onPicked) {
  return ProviderScope(
    overrides: [coreServiceProvider.overrideWithValue(svc)],
    child: MaterialApp(
      theme: RedtickTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async => onPicked(await showIssuePicker(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a query with no My-issues match auto-broadens to All visible',
      (tester) async {
    final svc = await loggedIn(tester, pickerBackend());
    addTearDown(svc.dispose);

    await tester.pumpWidget(host(svc, (_) {}));
    await tester.pump();

    await tester.tap(find.text('open'));
    await settle(tester); // dialog opens on the default My issues scope
    expect(find.text('Alpha issue'), findsOneWidget);
    expect(find.text('Zeta only in all'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zeta');
    await tester.pump(const Duration(milliseconds: 350)); // fire the debounce
    await settle(tester);

    // My issues returned nothing → the picker re-ran under All visible and the
    // broad-only issue is now shown.
    expect(find.text('Zeta only in all'), findsOneWidget);
    expect(find.text('Alpha issue'), findsNothing);
  });

  testWidgets('arrow-down + Enter starts the timer on the highlighted issue',
      (tester) async {
    final svc = await loggedIn(tester, pickerBackend());
    addTearDown(svc.dispose);

    IssueResult? picked;
    var popped = false;
    await tester.pumpWidget(host(svc, (r) {
      picked = r;
      popped = true;
    }));
    await tester.pump();

    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text('Alpha issue'), findsOneWidget);
    expect(find.text('Beta issue'), findsOneWidget);

    // Highlight starts on the first row; ↓ moves it to the second (Beta, #200).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    // Enter confirms via the search field's onSubmitted.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect(popped, isTrue);
    expect(picked, isNotNull);
    expect(picked!.id, 200);
    expect(picked!.subject, 'Beta issue');
  });
}
