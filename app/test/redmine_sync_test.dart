@TestOn('vm')
library;

// Cross-device sync (the running-timer poll). Two angles:
//  - RedmineApiClient.timeEntry(id): returns the entry, or null on 404 (deleted)
//  - the reconcile a poll triggers: a remote stop → refresh() clears the timer

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redtick/src/data/redmine_api_client.dart';
import 'package:redtick/src/data/redmine_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object o, [int s = 200]) =>
    http.Response(jsonEncode(o), s, headers: {'content-type': 'application/json'});

Map<String, dynamic> _entry({
  required int id,
  required String start,
  required String stop,
  String guid = '',
}) =>
    {
      'id': id,
      'project': {'id': 75},
      'issue': {'id': 23409},
      'activity': {'id': 6},
      'comments': '',
      'hours': 0.5,
      'spent_on': '2026-06-25',
      'custom_fields': [
        {'id': 12, 'name': 'toggl_start', 'value': start},
        {'id': 14, 'name': 'toggl_stop', 'value': stop},
        {'id': 13, 'name': 'toggl_guid', 'value': guid},
      ],
    };

/// A minimal Redmine backend whose recent time-entry list is supplied per call
/// by [entries], so a test can make an open entry appear/disappear between
/// pulls. The cheap single-entry poll path isn't exercised here (tests call
/// `refresh()` directly), so `/time_entries/{id}.json` just 404s.
MockClient _backend(List<Map<String, dynamic>> Function() entries) {
  return MockClient((req) async {
    final p = req.url.path;
    if (req.method == 'GET') {
      if (p.endsWith('/users/current.json')) {
        return _json({
          'user': {'id': 9, 'mail': 'me@x', 'firstname': 'Me', 'lastname': ''}
        });
      }
      if (p.endsWith('/projects.json')) {
        return _json({
          'projects': [
            {'id': 75, 'name': 'SUMA'}
          ],
          'total_count': 1
        });
      }
      if (p.endsWith('/issues.json')) {
        return _json({'issues': [], 'total_count': 0});
      }
      if (p.endsWith('/time_entry_activities.json')) {
        return _json({
          'time_entry_activities': [
            {'id': 6, 'name': 'Development', 'is_default': true, 'active': true}
          ]
        });
      }
      if (p.endsWith('/custom_fields.json')) {
        return _json({
          'custom_fields': [
            {'id': 12, 'name': 'toggl_start', 'customized_type': 'time_entry'},
            {'id': 14, 'name': 'toggl_stop', 'customized_type': 'time_entry'},
            {'id': 13, 'name': 'toggl_guid', 'customized_type': 'time_entry'},
          ]
        });
      }
      if (p.endsWith('/time_entries.json')) {
        final e = entries();
        return _json({'time_entries': e, 'total_count': e.length});
      }
    }
    return http.Response('not found', 404);
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('RedmineApiClient.timeEntry returns the entry, or null on 404', () async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/time_entries/1500.json')) {
        return _json({
          'time_entry':
              _entry(id: 1500, start: '2026-06-25T08:00:00Z', stop: '')
        });
      }
      return http.Response('not found', 404);
    });
    final api =
        RedmineApiClient(baseUrl: 'https://x', apiKey: 'k', client: client);

    final te = await api.timeEntry(1500);
    expect(te, isNotNull);
    expect(te!['id'], 1500);

    final gone = await api.timeEntry(9999); // 404 → deleted elsewhere
    expect(gone, isNull);
  });

  test('refresh reconciles a remote stop → running timer clears', () async {
    // The same entry: open at first, then stopped on "another device".
    var stopped = false;
    Map<String, dynamic> theEntry() => _entry(
          id: 1500,
          start: '2026-06-25T08:00:00Z',
          stop: stopped ? '2026-06-25T08:30:00Z' : '',
          guid: 'abc',
        );

    final client = MockClient((req) async {
      final p = req.url.path;
      if (req.method == 'GET') {
        if (p.endsWith('/users/current.json')) {
          return _json({
            'user': {'id': 9, 'mail': 'me@x', 'firstname': 'Me', 'lastname': ''}
          });
        }
        if (p.endsWith('/projects.json')) {
          return _json({
            'projects': [
              {'id': 75, 'name': 'SUMA'}
            ],
            'total_count': 1
          });
        }
        if (p.endsWith('/issues.json')) {
          return _json({'issues': [], 'total_count': 0});
        }
        if (p.endsWith('/time_entry_activities.json')) {
          return _json({
            'time_entry_activities': [
              {'id': 6, 'name': 'Development', 'is_default': true, 'active': true}
            ]
          });
        }
        if (p.endsWith('/custom_fields.json')) {
          return _json({
            'custom_fields': [
              {'id': 12, 'name': 'toggl_start', 'customized_type': 'time_entry'},
              {'id': 14, 'name': 'toggl_stop', 'customized_type': 'time_entry'},
              {'id': 13, 'name': 'toggl_guid', 'customized_type': 'time_entry'},
            ]
          });
        }
        if (p.endsWith('/time_entries.json')) {
          return _json({
            'time_entries': [theEntry()],
            'total_count': 1
          });
        }
      }
      return http.Response('not found', 404);
    });

    var clockNow = DateTime(2026, 6, 25, 9, 0, 0);
    final svc =
        await RedmineService.create(httpClient: client, clock: () => clockNow);
    addTearDown(svc.dispose);

    final running = svc.timerState.firstWhere((t) => t != null && t.isRunning);
    svc.setBaseUrl('https://x');
    svc.login('', 'key');
    await running.timeout(const Duration(seconds: 5)); // discovered running
    await Future<void>.delayed(const Duration(milliseconds: 50)); // settle

    // Remote stop. The drop-guard tolerates a single transient read-miss, so a
    // confirmed timer only clears after two consecutive reconciles past the
    // grace window — the two-confirmation contract that stops false flaps.
    stopped = true;
    clockNow = clockNow.add(const Duration(seconds: 60)); // past _dropGrace
    final cleared = svc.timerState.firstWhere((t) => t == null);
    await svc.refresh(); // miss #1 — still running (grace passed, streak = 1)
    expect(svc.currentTimer, isNotNull);
    await svc.refresh(); // miss #2 — now cleared
    await cleared.timeout(const Duration(seconds: 5));
    expect(svc.currentTimer, isNull);
  });

  test('a single transient read-miss keeps the running timer', () async {
    var present = true; // whether the open entry is returned by the list pull
    final client = _backend(() => present
        ? [
            _entry(
                id: 1500, start: '2026-06-25T08:00:00Z', stop: '', guid: 'abc')
          ]
        : const []);

    var clockNow = DateTime(2026, 6, 25, 9, 0, 0);
    final svc =
        await RedmineService.create(httpClient: client, clock: () => clockNow);
    addTearDown(svc.dispose);

    final running = svc.timerState.firstWhere((t) => t != null && t.isRunning);
    svc.setBaseUrl('https://x');
    svc.login('', 'key');
    await running.timeout(const Duration(seconds: 5)); // discovered running

    // Past the grace window, the entry vanishes for a single pull (server lag /
    // recent-window eviction) then returns — it must NOT be dropped.
    clockNow = clockNow.add(const Duration(seconds: 60));
    present = false;
    await svc.refresh();
    expect(svc.currentTimer, isNotNull, reason: 'one miss must not drop');
    present = true;
    await svc.refresh();
    expect(svc.currentTimer, isNotNull, reason: 're-seen → streak resets');
    // And it survives subsequent pulls while visible.
    await svc.refresh();
    expect(svc.currentTimer, isNotNull);
  });

  test('a confirmed timer within the grace window is never dropped', () async {
    var present = true;
    final client = _backend(() => present
        ? [
            _entry(
                id: 1500, start: '2026-06-25T08:00:00Z', stop: '', guid: 'abc')
          ]
        : const []);

    var clockNow = DateTime(2026, 6, 25, 9, 0, 0);
    final svc =
        await RedmineService.create(httpClient: client, clock: () => clockNow);
    addTearDown(svc.dispose);

    final running = svc.timerState.firstWhere((t) => t != null && t.isRunning);
    svc.setBaseUrl('https://x');
    svc.login('', 'key');
    await running.timeout(const Duration(seconds: 5));

    // The entry vanishes while still inside the grace window (clock barely
    // moved): even two consecutive reconciles must NOT drop it.
    clockNow = clockNow.add(const Duration(seconds: 10)); // < _dropGrace (45s)
    present = false;
    await svc.refresh();
    await svc.refresh();
    expect(svc.currentTimer, isNotNull);
  });
}
