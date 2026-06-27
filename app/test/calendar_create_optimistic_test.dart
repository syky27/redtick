@TestOn('vm')
library;

// createEntryAt (calendar tap-to-create) must feel instant: the entry shows
// optimistically before the POST + refresh round-trip, then reconciles to the
// single authoritative server row (matched by toggl_guid) with no duplicate.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redtick/src/data/redmine_service.dart';
import 'package:redtick/src/models/time_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal stateful Redmine backend: POST /time_entries appends to [store] and
/// echoes a new id; GET /time_entries returns the live collection so a refresh
/// reflects the just-created row.
http.Client backend(List<Map<String, dynamic>> store,
    {List<Map<String, dynamic>>? posts}) {
  var nextId = 5000;
  http.Response j(Object o, [int s = 200]) => http.Response(jsonEncode(o), s,
      headers: {'content-type': 'application/json'});

  return MockClient((req) async {
    final p = req.url.path;
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
      if (p.endsWith('/issues.json')) {
        return j({
          'issues': [
            {
              'id': 23409,
              'subject': 'Demo issue',
              'project': {'id': 75, 'name': 'SUMA'},
              'status': {'name': 'In Progress', 'is_closed': false},
            }
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
        return j({'time_entries': store, 'total_count': store.length});
      }
    }
    if (req.method == 'POST' && p.endsWith('/time_entries.json')) {
      final body =
          (jsonDecode(req.body) as Map)['time_entry'] as Map<String, dynamic>;
      posts?.add(body);
      final cfs = (body['custom_fields'] as List).cast<Map>();
      String cf(int id) => (cfs.firstWhere((c) => c['id'] == id,
          orElse: () => {'value': ''})['value'] as String);
      final id = nextId++;
      store.add({
        'id': id,
        'project': {'id': body['project_id'] ?? 75},
        'issue': {'id': body['issue_id'] ?? 23409},
        'activity': {'id': body['activity_id'] ?? 6},
        'comments': body['comments'] ?? '',
        'hours': (body['hours'] as num?) ?? 0,
        'spent_on': '2026-06-25',
        'custom_fields': [
          {'id': 12, 'name': 'toggl_start', 'value': cf(12)},
          {'id': 14, 'name': 'toggl_stop', 'value': cf(14)},
          {'id': 13, 'name': 'toggl_guid', 'value': cf(13)},
        ],
      });
      return j({
        'time_entry': {'id': id}
      }, 201);
    }
    return http.Response('not found', 404);
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('createEntryAt surfaces the entry optimistically, then reconciles to one '
      'server row', () async {
    final store = <Map<String, dynamic>>[];
    final posts = <Map<String, dynamic>>[];
    final svc = await RedmineService.create(httpClient: backend(store, posts: posts));
    addTearDown(svc.dispose);

    final loggedIn = svc.loginState.firstWhere((e) => e.loggedIn);
    svc.setBaseUrl('https://x');
    svc.login('', 'key');
    await loggedIn.timeout(const Duration(seconds: 5));

    bool hasOptimistic(List<TimeEntry> l) =>
        l.any((e) => !e.isHeader && e.description == 'Optimistic');

    // Subscribe before creating so we catch the very first emission.
    final firstAfterCreate =
        svc.timeEntries.firstWhere(hasOptimistic);

    final start = DateTime(2026, 6, 25, 9, 0);
    final end = DateTime(2026, 6, 25, 9, 30);
    final done = svc.createEntryAt(
      issueId: 23409,
      projectId: 75,
      start: start,
      end: end,
      description: 'Optimistic',
      subject: 'Demo issue',
      projectName: 'SUMA',
    );

    // The optimistic placeholder lands before the refresh reconciles it:
    // exactly one row, no server id yet (a refreshed row would carry one).
    final optimistic = (await firstAfterCreate.timeout(const Duration(seconds: 5)))
        .where((e) => !e.isHeader && e.description == 'Optimistic')
        .toList();
    expect(optimistic, hasLength(1));
    expect(optimistic.first.id, 0, reason: 'placeholder carries no server id');

    await done.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // After POST + refresh: still exactly one row, now backed by the server id.
    final settled = svc.currentTimeEntries!
        .where((e) => !e.isHeader && e.description == 'Optimistic')
        .toList();
    expect(posts, hasLength(1));
    expect(settled, hasLength(1), reason: 'no duplicate after reconcile');
    expect(settled.first.id, greaterThan(0),
        reason: 'reconciled to the authoritative server row');
  });
}
