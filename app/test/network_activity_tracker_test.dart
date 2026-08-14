@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redtick/src/data/network_activity.dart';
import 'package:redtick/src/data/redmine_api_client.dart';

void main() {
  group('counter', () {
    test('track increments then decrements; overlap reaches 2', () async {
      final t = NetworkActivityTracker();
      final counts = <int>[];
      final sub = t.activeRequests.listen(counts.add);

      final a = Completer<void>();
      final b = Completer<void>();
      final fa = t.track(() => a.future);
      final fb = t.track(() => b.future);
      a.complete();
      await fa;
      b.complete();
      await fb;
      await Future<void>.delayed(Duration.zero);

      expect(counts, [1, 2, 1, 0]);
      expect(t.active, 0);
      await sub.cancel();
      t.dispose();
    });

    test('a throwing op still decrements and rethrows', () async {
      final t = NetworkActivityTracker();
      await expectLater(
          t.track<void>(() async => throw StateError('boom')),
          throwsStateError);
      expect(t.active, 0);
      t.dispose();
    });
  });

  group('background bracket', () {
    test('requests inside runBackground are not counted', () async {
      final t = NetworkActivityTracker();
      final counts = <int>[];
      final sub = t.activeRequests.listen(counts.add);

      await t.runBackground(() => t.track(() async {}));
      await Future<void>.delayed(Duration.zero);

      expect(counts, isEmpty);
      expect(t.active, 0);
      await sub.cancel();
      t.dispose();
    });

    test('nested runBackground stays muted', () async {
      final t = NetworkActivityTracker();
      await t.runBackground(
          () => t.runBackground(() => t.track(() async {})));
      expect(t.active, 0);
      t.dispose();
    });

    test('request started before a bracket still decrements the counter',
        () async {
      final t = NetworkActivityTracker();
      final gate = Completer<void>();
      final f = t.track(() => gate.future); // counted: no bracket yet
      expect(t.active, 1);
      final bg = t.runBackground(() async {
        gate.complete(); // request finishes while the bracket is active
        await f;
      });
      await bg;
      expect(t.active, 0);
      t.dispose();
    });
  });

  group('smoothing', () {
    test('a fast request never emits busy', () {
      fakeAsync((async) {
        final t = NetworkActivityTracker();
        final events = <bool>[];
        t.busy.listen(events.add);

        t.track(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        async.elapse(const Duration(seconds: 2));

        expect(events, isEmpty);
        expect(t.busyNow, isFalse);
        t.dispose();
      });
    });

    test('a slow request shows at 150ms and hides after it completes', () {
      fakeAsync((async) {
        final t = NetworkActivityTracker();
        final events = <bool>[];
        t.busy.listen(events.add);

        t.track(() => Future<void>.delayed(const Duration(milliseconds: 500)));
        async.elapse(const Duration(milliseconds: 149));
        expect(t.busyNow, isFalse);
        async.elapse(const Duration(milliseconds: 2));
        expect(t.busyNow, isTrue);
        async.elapse(const Duration(milliseconds: 400));
        expect(t.busyNow, isFalse);
        expect(events, [true, false]);
        t.dispose();
      });
    });

    test('min-show holds busy until 500ms for a request done at 200ms', () {
      fakeAsync((async) {
        final t = NetworkActivityTracker();
        final events = <bool>[];
        t.busy.listen(events.add);

        t.track(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        // Shown at 150ms; request ends at 200ms; min-show (350ms from 150ms)
        // keeps it visible until 500ms.
        async.elapse(const Duration(milliseconds: 499));
        expect(t.busyNow, isTrue);
        async.elapse(const Duration(milliseconds: 2));
        expect(t.busyNow, isFalse);
        expect(events, [true, false]);
        t.dispose();
      });
    });

    test('two requests with a short gap produce a single true/false pair', () {
      fakeAsync((async) {
        final t = NetworkActivityTracker();
        final events = <bool>[];
        t.busy.listen(events.add);

        t.track(() => Future<void>.delayed(const Duration(milliseconds: 400)));
        async.elapse(const Duration(milliseconds: 410));
        // 10ms gap (like a paged fetch), then a second slow request.
        t.track(() => Future<void>.delayed(const Duration(milliseconds: 400)));
        async.elapse(const Duration(seconds: 2));

        expect(events, [true, false]);
        t.dispose();
      });
    });
  });

  group('RedmineApiClient wiring', () {
    MockClient okClient() => MockClient((req) async => http.Response(
          jsonEncode({
            'user': {'id': 1},
            'time_entry': {'id': 7},
          }),
          200,
          headers: {'content-type': 'application/json'},
        ));

    test('GET and POST both bump activeRequests', () async {
      final t = NetworkActivityTracker();
      final counts = <int>[];
      final sub = t.activeRequests.listen(counts.add);
      final api = RedmineApiClient(
          baseUrl: 'https://x', apiKey: 'k', client: okClient(), tracker: t);

      await api.currentUser(); // GET via _getJson
      await api.createTimeEntry(
        // POST via _send
        issueId: 1,
        projectId: 0,
        hours: 0.5,
        spentOn: DateTime(2026, 1, 1),
        comments: '',
        activityId: 9,
        togglStart: '',
        togglStop: '',
        togglGuid: '',
        cfStart: 0,
        cfStop: 0,
        cfGuid: 0,
      );
      await Future<void>.delayed(Duration.zero);

      expect(counts, [1, 0, 1, 0]);
      api.dispose();
      await sub.cancel();
      t.dispose();
    });
  });
}
