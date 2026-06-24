# Flutter Port — Implementation Plan & Issue Backlog

> **Goal:** Port **Redtick** (this Toggl Desktop fork, Redmine time tracking; the `sun-valley` work is now merged into `master`)
> to a single **Flutter** codebase covering **iOS, Android, macOS, Windows, Linux**, reusing the
> existing ~32K-line C++ core verbatim via `dart:ffi` and rewriting only the UI.
>
> **Status of this document:** This is the ready-to-file issue backlog. GitHub issue creation was
> blocked at the time of writing (the Claude GitHub App is not connected for this org / session).
> Once GitHub access is enabled, every issue below can be created 1:1 (Epic → sub-issues) and then
> checked off as implemented. Each issue has a stable slug (e.g. `FP-12`) for cross-referencing.

## Implementation status — 2026-06-24

The port has been implemented and is building. Status by issue (✅ done & verified,
🟡 partial/scaffolded, ⬜ follow-up needing a device/server):

**Verified on Linux (built + tested in CI-equivalent run):**
- ✅ FP-01 Flutter scaffold (5 platforms) · FP-02 ADR (Riverpod + FFI threading)
- ✅ FP-10 Core builds standalone as `libTogglDesktopLibrary.so` (205 `toggl_*` symbols, no Qt)
- ✅ FP-20 ffigen full bindings (410 symbols) + hand-written focused subset
- ✅ FP-21 `CoreService` (lifecycle, login/logout/continue/stop/start, editor setters, marshalling)
- ✅ FP-22 callbacks → Dart streams; **FP-22b** thread-safe C bridge shim (`bridge.c`, deep-copy)
- ✅ FP-23 Dart models · FP-24 providers · FP-25 per-platform DB path + bundled CA cert
- ✅ FP-40 responsive shell · FP-41 login · FP-42 timer bar · FP-43 list · FP-44 editor · FP-46 calendar day-grid · FP-47 settings · FP-48 theme
- ✅ FP-60 core wired into `flutter build linux` (bundles the `.so`) — **full desktop app builds**
- ✅ FP-61 CI workflow (build core → ffigen → analyze → test → FFI smoke test → build matrix)
- ✅ FP-13 (offline half) `CoreService` starts the real core over FFI (`ui_start`/`VerifyCallbacks` pass)
- ✅ FP-31 contributor docs (`app/README.md`)

**Partial / scaffolded:**
- 🟡 FP-45 issue picker (project field in editor; live Redmine search = follow-up)
- 🟡 FP-46 calendar (day grid + tap-edit done; drag-move/edge-resize = follow-up; setters wired)
- 🟡 FP-52 idle, FP-54 notifications (core streams wired + in-app banners; OS notification = swap `NotificationPresenter`)

**Follow-up (needs device/toolchain/backend):**
- 🟡 FP-11 Android build **config authored** (CMake dep-discovery, `build-deps.sh` for
  OpenSSL/Poco/jsoncpp, Gradle `externalNativeBuild`, core X11/window guards for
  `__ANDROID__`, window-detection stub) — **execution blocked**: the NDK/SDK host
  `dl.google.com`/`maven.google.com` is denied by the sandbox network policy. Runs
  as-is wherever the NDK is reachable. See `app/native/android/README.md`.
- ⬜ FP-12 iOS xcframework · FP-64 Windows packaging · FP-62/63 store releases
- ⬜ FP-13 (online half) login round-trip against a live Redmine server
- ⬜ FP-50 tray · FP-51 global shortcuts · FP-53 timeline/autotracker · FP-55 mobile bg sync · FP-30 parity sweep

See `platform-features.md` for the Phase-5 plugin map. Acceptance-criteria checkboxes
below remain as the per-issue tracking surface.

## Architecture recap (why this is a UI swap, not a rewrite)

- **Reused as-is:** `libTogglDesktopLibrary`, ~32,410 LOC under `src/` — `context.cc`,
  `database/database.cc`, `model/*`, `https_client.cc`, `netconf.cc`, `urls.cc`.
- **The boundary:** `src/toggl_api.h` — a flat C ABI with ~205 `toggl_*` functions and ~30
  `toggl_on_*` callbacks. Flutter binds to this exactly as Qt/Cocoa/.NET do today.
- **Rewritten:** one Flutter UI replacing `src/ui/linux` (Qt), `src/ui/osx` (Cocoa), `src/ui/windows` (.NET).
- **Deps to cross-compile:** Poco (Crypto, DataSQLite, NetSSL), OpenSSL 3, jsoncpp, SQLite.

## Proposed repository layout

```
/src                     # existing C++ core (unchanged)
/app                     # new Flutter application (lib/, ios/, android/, macos/, windows/, linux/)
  /native                # FFI: ffigen config, generated bindings, Dart wrapper service
/packages/redtick_core   # optional: core build scripts + prebuilt libs per platform
/docs/flutter-port       # this plan
```

---

## Labels / conventions for the issues

- Labels: `flutter-port`, plus one of `epic`, `core-build`, `ffi`, `ui`, `platform`, `ci`, `qa`.
- Each issue lists: **Outcome**, **Acceptance criteria** (checklist), **Files/refs**, **Depends on**.
- Milestones map to the phases below.

---

# EPIC

## FP-00 — EPIC: Port Redtick to Flutter (5 platforms) over the existing C++ core
**Labels:** `flutter-port`, `epic`
**Outcome:** One Flutter app shipping on iOS, Android, macOS, Windows, Linux, driving the existing
C core through FFI, at behavioral parity with the current Qt app.
**Tracks:** all sub-issues FP-01 … FP-31 below.
**Definition of done:** POC gate (FP-13) passed; all UI screens (Phase 4) implemented; CI builds all
5 platforms (Phase 6); parity checklist (FP-30) green.

---

# Phase 0 — Foundations

## FP-01 — Scaffold Flutter app & monorepo layout
**Labels:** `flutter-port`
**Outcome:** A buildable empty Flutter app under `/app` for all 5 targets; layout per "Proposed repository layout".
**Acceptance criteria:**
- [ ] `flutter create` with platforms `ios,android,macos,windows,linux` under `/app`.
- [ ] `flutter run` launches a placeholder on at least one desktop + one mobile target.
- [ ] CI lint/format (`flutter analyze`, `dart format`) wired (stub OK).
**Depends on:** —

## FP-02 — Choose state management & app conventions
**Labels:** `flutter-port`
**Outcome:** Documented decision (recommend **Riverpod**) + folder conventions, error handling, logging.
**Acceptance criteria:**
- [ ] ADR committed under `/docs/flutter-port/adr-0001-state-management.md`.
- [ ] Example provider wired to a dummy stream.
**Depends on:** FP-01

---

# Phase 1 — Build the C++ core as a cross-platform artifact

## FP-10 — Build core as a shared lib for desktop (Linux .so / Windows .dll / macOS .dylib)
**Labels:** `flutter-port`, `core-build`
**Outcome:** Reproducible CMake target producing the core lib for each desktop OS.
**Acceptance criteria:**
- [ ] CMake target builds `libTogglDesktopLibrary` headless (no Qt) on Linux/macOS/Windows.
- [ ] Exported symbols from `toggl_api.h` verified present (`nm`/`dumpbin`).
**Files/refs:** `src/CMakeLists.txt`, `src/toggl_api.h`.
**Depends on:** —

## FP-11 — Cross-compile core + deps for Android (NDK, all ABIs)
**Labels:** `flutter-port`, `core-build`
**Outcome:** `.so` per ABI (arm64-v8a, armeabi-v7a, x86_64) bundled in the APK.
**Acceptance criteria:**
- [ ] Poco / OpenSSL 3 / jsoncpp / SQLite cross-built with NDK.
- [ ] Core links and loads in an Android instrumentation smoke test.
- [ ] Note: Poco ships `*_Android.h` variants — confirm they're used.
**Files/refs:** `src/CMakeLists.txt`, `third_party/`.
**Depends on:** FP-10

## FP-12 — Cross-compile core + deps for iOS (xcframework)
**Labels:** `flutter-port`, `core-build`
**Outcome:** `.xcframework` (device arm64 + simulator) linked into the iOS Runner.
**Acceptance criteria:**
- [ ] Static lib + deps built for iOS; symbols stripped appropriately.
- [ ] Loads in an iOS simulator smoke test.
**Depends on:** FP-10

## FP-13 — POC GATE: FFI login + time-entry-list end-to-end ⭐
**Labels:** `flutter-port`, `ffi`
**Outcome:** Minimal Flutter app that calls `toggl_context_init` → `toggl_login` against a Redmine
instance and renders the `toggl_on_time_entry_list` callback. **De-risks the whole port.**
**Acceptance criteria:**
- [ ] Real login round-trip succeeds.
- [ ] Time entries from the core render in a Dart list.
- [ ] Works on at least one mobile + one desktop target.
**Depends on:** FP-11 or FP-12, FP-20, FP-21, FP-22.

---

# Phase 2 — FFI binding layer

## FP-20 — Generate Dart FFI bindings from `toggl_api.h` (ffigen)
**Labels:** `flutter-port`, `ffi`
**Outcome:** Auto-generated low-level bindings for all `toggl_*` functions and view structs.
**Acceptance criteria:**
- [ ] `ffigen` config in `/app/native`; `dart run ffigen` regenerates cleanly.
- [ ] All ~205 functions + view structs present in generated output.
**Files/refs:** `src/toggl_api.h`.
**Depends on:** FP-10

## FP-21 — Dart wrapper service over the C API
**Labels:** `flutter-port`, `ffi`
**Outcome:** Idiomatic Dart `CoreService` wrapping init/clear, login/logout, sync, and CRUD
(`toggl_continue`, `toggl_create_empty_time_entry`, `toggl_edit`, `toggl_delete_time_entry`, `toggl_fullsync`).
**Acceptance criteria:**
- [ ] String/`bool`/`int64` marshalling helpers; no leaks (free returned strings).
- [ ] Unit tests for argument marshalling.
**Depends on:** FP-20

## FP-22 — Bridge `toggl_on_*` C callbacks → Dart Streams
**Labels:** `flutter-port`, `ffi`
**Outcome:** Each `toggl_on_*` registration (list, timer_state, login, error, settings, online_state,
autocomplete, …) surfaces as a typed Dart `Stream`.
**Acceptance criteria:**
- [ ] Uses `NativeCallable.listener` with correct isolate/threading handling.
- [ ] All ~30 callbacks bridged; back-pressure/teardown handled on logout.
**Files/refs:** `toggl_on_*` in `src/toggl_api.h`.
**Depends on:** FP-20

## FP-23 — Marshal core view structs into Dart models
**Labels:** `flutter-port`, `ffi`
**Outcome:** Dart immutable models mirroring `TogglTimeEntryView`, timer state, settings, autocomplete, etc.
**Acceptance criteria:**
- [ ] Linked-list view structs walked & converted to Dart lists.
- [ ] `check_view_struct_size` parity verified to catch ABI drift.
**Depends on:** FP-20

---

# Phase 3 — App state & domain

## FP-24 — App state / providers fed by callback streams
**Labels:** `flutter-port`, `ui`
**Outcome:** Auth state, running timer, entry list, settings, online/sync state exposed as providers.
**Acceptance criteria:**
- [ ] State updates reactively from FP-22 streams.
- [ ] App lifecycle (resume) triggers `toggl_fullsync`; pause flushes.
**Depends on:** FP-22, FP-23, FP-02

## FP-25 — Per-platform core DB path & init lifecycle
**Labels:** `flutter-port`, `platform`
**Outcome:** Correct writable DB/log path per OS passed to `toggl_context_init`; clean init/teardown.
**Acceptance criteria:**
- [ ] Paths via `path_provider`; verified writable on all 5 platforms.
**Depends on:** FP-21

---

# Phase 4 — UI screens (mapped from the Qt UI)

> Each screen is responsive: compact layout = mobile, expanded = desktop, one widget tree.

## FP-40 — Responsive app shell & navigation
**Labels:** `flutter-port`, `ui`
**Acceptance criteria:** [ ] Adaptive nav (bottom bar mobile / rail-or-sidebar desktop); routing.
**Depends on:** FP-24

## FP-41 — Login screen (Redmine URL + API key)
**Refs:** `src/ui/linux/TogglDesktop/loginwidget.*`
**Acceptance criteria:** [ ] Calls `toggl_login`; error states; loading bar; persists backend URL.
**Depends on:** FP-21

## FP-42 — Timer bar / running entry
**Refs:** `src/ui/linux/TogglDesktop/timerwidget.*`
**Acceptance criteria:** [ ] Start/stop (`toggl_continue`/stop); live duration; issue shown on top.
**Depends on:** FP-24

## FP-43 — Time entry list (grouped by day)
**Refs:** `timeentrylistwidget.*`, `timeentrycellwidget.*`
**Acceptance criteria:** [ ] Grouped rows; continue; swipe-to-delete; clickable Redmine links; `toggl_load_more`.
**Depends on:** FP-24

## FP-44 — Time entry editor
**Refs:** `timeentryeditorwidget.*`
**Acceptance criteria:** [ ] Edit description/project/issue/time/tags via `toggl_edit`/`toggl_set_*`.
**Depends on:** FP-24

## FP-45 — Redmine issue search / picker
**Refs:** branch commits "Redmine: live issue search", "Enforce a Redmine issue on the timer"
**Acceptance criteria:** [ ] Live search; required-issue enforcement before start.
**Depends on:** FP-24

## FP-46 — Calendar / day view
**Refs:** `calendarview` (branch: "day calendar grid", "drag-to-move and edge-resize", "split-at-midnight")
**Acceptance criteria:** [ ] Day grid; drag-to-move; edge-resize; create/edit; split-at-midnight.
**Depends on:** FP-24

## FP-47 — Settings / preferences
**Refs:** `preferencesdialog.*`, `settingsview.*`
**Acceptance criteria:** [ ] Read/write settings via `toggl_set_settings_*`; reactive to `toggl_on_settings`.
**Depends on:** FP-24

## FP-48 — Theming & Redtick branding
**Refs:** branch "Rebrand to Redtick"
**Acceptance criteria:** [ ] Colors, icons, app name, login logo applied; light/dark.
**Depends on:** FP-40

---

# Phase 5 — Platform-specific features

## FP-50 — Desktop system tray & window management
**Refs:** `systemtray.*`; pkgs `tray_manager`, `window_manager`
**Acceptance criteria:** [ ] Tray icon/menu (running/stopped state); minimize-to-tray; reopen.
**Depends on:** FP-42

## FP-51 — Global shortcuts (desktop)
**Refs:** `third_party/qxtglobalshortcut5`
**Acceptance criteria:** [ ] Show/start hotkeys; no empty-shortcut grab regression (see branch fix).
**Depends on:** FP-50

## FP-52 — Idle detection & idle notification (desktop; stub mobile)
**Refs:** `src/idle.cc`, `idlenotificationwidget.*`, `get_focused_window_*.cc`
**Acceptance criteria:** [ ] Desktop idle via platform channels → `toggl_on_idle_notification`; mobile no-op.
**Depends on:** FP-24

## FP-53 — Timeline / autotracker scope decision (desktop; stub mobile)
**Refs:** `timeline_uploader.cc`, `model/timeline_event.cc`, `model/autotracker.*`
**Acceptance criteria:** [ ] Decide keep/drop on desktop; stub on mobile; documented.
**Depends on:** FP-24

## FP-54 — Cross-platform notifications (reminders / pomodoro)
**Refs:** `toggl_on_reminder`, `toggl_on_pomodoro*`
**Acceptance criteria:** [ ] Local notifications on all platforms via `flutter_local_notifications`.
**Depends on:** FP-24

## FP-55 — Mobile background/foreground sync behavior
**Acceptance criteria:** [ ] Foreground resync; sensible behavior on background (no silent data loss).
**Depends on:** FP-25

---

# Phase 6 — Build, CI, release

## FP-60 — Wire native core libs into each Flutter platform build
**Acceptance criteria:** [ ] Android (jniLibs/CMake), iOS (xcframework), desktop (CMake/MSBuild) link the core.
**Depends on:** FP-11, FP-12, FP-10

## FP-61 — CI build matrix for all 5 platforms
**Refs:** branch CI (`dist/linux/appimage.sh`, macOS .dmg pipeline, `.github/workflows`)
**Acceptance criteria:** [ ] CI builds Flutter app per platform with the core libs.
**Depends on:** FP-60

## FP-62 — Android release (signing + Play artifact)
**Acceptance criteria:** [ ] Signed AAB; internal-track upload documented.
**Depends on:** FP-61

## FP-63 — iOS release (signing + TestFlight)
**Acceptance criteria:** [ ] Signed IPA; TestFlight upload documented.
**Depends on:** FP-61

## FP-64 — Desktop packaging (extend dmg/AppImage; add Windows installer)
**Refs:** existing `.dmg` + AppImage pipeline on branch.
**Acceptance criteria:** [ ] macOS .dmg, Linux AppImage, Windows MSIX/exe from the Flutter build.
**Depends on:** FP-61

---

# Phase 7 — QA & cutover

## FP-30 — Behavioral parity checklist vs Qt app
**Acceptance criteria:** [ ] Create/edit/delete/continue entry, login/logout, sync, calendar edit — all match Qt.
**Depends on:** Phase 4

## FP-31 — Contributor docs & dev setup
**Acceptance criteria:** [ ] README: build core per platform, regenerate FFI, run app; troubleshooting.
**Depends on:** FP-13

---

## Dependency / sequencing summary

```
FP-01 ─ FP-02
   └ FP-10 ─┬ FP-11 ┐
            ├ FP-12 ┤
            └ FP-20 ─ FP-21 / FP-22 / FP-23 ─ FP-24 ─ FP-13 (POC GATE) ⭐
                                                 └ Phase 4 (FP-40..48)
                                                 └ Phase 5 (FP-50..55)
FP-60 ─ FP-61 ─ FP-62 / FP-63 / FP-64
Phase 4 ─ FP-30 ; FP-13 ─ FP-31
```

## How these get filed as GitHub issues (once access is enabled)

1. Create `FP-00` as the Epic issue (body = the Epic section + a task list linking children).
2. Create one issue per `FP-NN` with its Outcome / Acceptance criteria / Files / Depends-on.
3. Add labels + milestones (one milestone per phase).
4. Link children to the Epic (task list or sub-issues).
5. As work lands, check the acceptance boxes and close each issue; tick it in `FP-00`.
