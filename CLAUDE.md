# Redtick — Claude Code guide

**Redtick** is a community fork of Toggl Desktop, retargeted from the Toggl cloud
to **Redmine**. It is now **one Flutter codebase** (`app/`, package `redtick`) for
macOS, Windows, Linux, iOS, and Android, talking to **Redmine REST directly over HTTP**.

## The one thing to know
There is **no C++/Qt/Cocoa/WPF, no FFI, no native core, no SQLite, no code-gen**.
The legacy native tree (`src/`, `src/ui/*`) was deleted (commit `304431f12`); the
backend is **pure Dart**. References to `toggl_api.h`, `ffigen`, `app/native/bridge.c`,
POCO, or a CMake core build are historical — ignore them. All work happens in **`app/`**.

## Commands (run from `app/`)
```bash
flutter pub get
flutter run -d macos        # or windows / linux / a connected device
flutter analyze             # flutter_lints; keep green (CI gate)
flutter test                # pure-Dart suite under app/test/
flutter build macos --release   # or windows / linux
```
- Flutter **stable, pinned to 3.44.3** in CI; Dart SDK `^3.12.2`.
- **No build_runner / code generation.** Models are hand-written; JSON parsed with `jsonDecode`.
- Icons/splash only when assets change: `dart run tool/generate_icons.dart && dart run
  flutter_launcher_icons`, then `dart run flutter_native_splash:create`.

## Layout (`app/lib/`)
- `main.dart` — entry: builds `RedmineService`, injects it into a Riverpod `ProviderScope`.
- `src/data/` — pure-Dart Redmine backend: `redmine_api_client.dart` (thin REST),
  `redmine_service.dart` (streams + persistence + sync), `offline_queue.dart`,
  `release_watch_service.dart`.
- `src/models/` — immutable models (`time_entry.dart`).
- `src/state/` — Riverpod: `providers.dart` (StreamProviders over the service) + per-domain
  `NotifierProvider`s (idle, reminders, theme, multi-task, view, release-watch).
- `src/platform/` — OS hooks: notifications, iOS Live Activity, idle detection, background reconcile.
- `src/ui/` — `app.dart`, `theme.dart`, `screens/` (login, home shell, list, editor,
  calendar, settings), `widgets/`.
- `app/test/` — pure-Dart unit + widget tests.

## Conventions
- **State = Riverpod.** `RedmineService` exposes broadcast `Stream`s; UI consumes via
  `StreamProvider`/`NotifierProvider`. Widgets are `ConsumerWidget`/`ConsumerStatefulWidget`
  and `ref.watch(...)` — **no mutable widget state**, no business logic in `State`.
- Models are **immutable**; state changes flow as new emissions.
- API key lives in the **OS keychain** (`flutter_secure_storage`) — never in
  `shared_preferences`/plaintext. Other prefs use `shared_preferences`.
- Offline writes are **queued and retried** (`offline_queue.dart`).
- HTTP via the `http` package (not dio).

## Redmine domain rules (invariants — don't break)
- The Redmine **base URL is runtime-configurable** (entered at login); every call targets that one host.
- **Every time entry must link a Redmine issue** — the timer refuses to start without one.
- Three **time-entry custom fields** carry the extra timer data: `toggl_start`, `toggl_stop`,
  `toggl_guid`. They are **resolved by name at login** (never hardcoded ids). The `toggl_*`
  names are deliberate Redmine field names — **not** leftover Toggl-cloud code.
- A timer crossing **local midnight** is split into one entry per day (Redmine stores per-day hours).
- Authoritative REST details: `docs/flutter-port/REDMINE_API_CONTRACT.md`.

## Historical docs — treat as superseded
`docs/flutter-port/adr-0001-state-management.md` and `IMPLEMENTATION_PLAN.md` describe an
**earlier, abandoned plan** to drive the old C++ core via FFI (`ffigen`, `app/native/bridge.c`,
`toggl_api.h`). That never shipped — the backend is pure Dart. Use them only as history.
(The ADR's **Riverpod** choice still holds.) Current sources of truth: this file, `README.md`,
`app/README.md`, `REDMINE_API_CONTRACT.md`.

## Notes
- The code is almost entirely **Claude-authored**, built and verified but worth reviewing.
- Global `~/.claude/CLAUDE.md` rules still apply (clean commits, no AI attribution, no
  commit/push without explicit approval).
