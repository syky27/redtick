<h1 align="center">
  <img src="docs/redtick-wordmark.png" alt="Redtick" width="420">
</h1>

<h4 align="center">A Redmine-native time tracker — the Toggl Desktop experience, wired straight to your own <a href="https://www.redmine.org" target="_blank">Redmine</a>.</h4>

<p align="center">
  <img src="https://img.shields.io/badge/backend-Redmine-A11C1C?style=flat" alt="Redmine backend">
  <img src="https://img.shields.io/badge/built%20with-Claude%20Code-D97757?style=flat" alt="Built with Claude Code">
  <img src="https://img.shields.io/badge/macOS-verified-444?style=flat" alt="macOS verified">
  <img src="https://img.shields.io/badge/licence-BSD--3-green" alt="Licence BSD-3">
</p>

<p align="center">
  <a href="#about">About</a> •
  <a href="#built-with-claude-code">Built with Claude Code</a> •
  <a href="#how-it-works">How it works</a> •
  <a href="#configure">Configure</a> •
  <a href="#build">Build</a> •
  <a href="#credits">Credits</a>
</p>

# About

**Redtick** is a community fork of [Toggl Desktop](https://github.com/toggl-open-source/toggldesktop) that swaps the Toggl cloud backend for **Redmine**. You keep the fast, friendly desktop timer, but every entry you track lands in your own Redmine instance instead of Toggl's servers.

No Toggl account. No third-party cloud. Your time data stays on the Redmine server you point it at.

What it does today (verified on macOS):

- **Log in with a Redmine URL + personal API key** — no passwords, no OAuth, no SSO.
- **Projects and your issues load automatically**, and you can **search any issue your token can see** — by issue number or by text, not just the ones assigned to you.
- **Start/stop a timer on a Redmine issue.** On stop it creates a Redmine time entry with `hours`, `spent_on`, `activity`, comments, and the exact start/stop timestamps stored in custom fields. Edits `PUT`, deletes `DELETE`.
- **Every entry must be linked to a Redmine issue** — the timer refuses to start without one.
- **Day calendar view** with draggable blocks: move/resize entries, click an empty slot to create one, click a block to edit. A timer that runs past local midnight is split into one entry per day so Redmine's per-day hours stay correct.
- **Activity picker** — choose a default activity in Preferences and override it per entry; activities are pulled live from Redmine.
- **Pause-on-idle**, reminders and Pomodoro carry over from Toggl Desktop. The idle prompt lets you keep or discard idle time.

# Built with Claude Code

This fork was implemented **almost entirely by [Claude Code](https://claude.com/claude-code)** (Anthropic) — the Redmine backend retarget, the removal of Toggl-only cruft, the calendar/issue-picker UI, and this RedTick rebrand. Every commit on this branch is Claude-attributed by design. Treat the code accordingly: it has been built and verified, but it is AI-authored and benefits from review before you rely on it.

# How it works

Redtick is a single **Flutter** codebase (`app/`) that talks to **Redmine directly
over HTTP** — no Toggl cloud, no native C++ core. Login points the app at a
**runtime-configurable Redmine base URL**; every call resolves to that one host.

A pure-Dart client — `RedmineApiClient` + `RedmineService` (`app/lib/src/data/`) —
fans the session out across Redmine's `/users/current`, `/projects`, `/issues`,
`/time_entries` and activity endpoints and feeds the Riverpod state the UI renders.
A running timer is stored as a Redmine time entry whose start/stop timestamps and
GUID live in custom fields. The base URL is entered on the login screen and the API
key is kept in the OS keychain (`flutter_secure_storage`); offline writes are queued
and retried. See `app/README.md` and `docs/flutter-port/` for the architecture, the
Redmine API contract, and platform-feature notes.

# Configure

1. Launch Redtick.
2. On the login screen, enter the URL of your Redmine instance (e.g. `https://redmine.example.com`) and your personal **API key** (Redmine → *My account* → *API access key*).
3. Start tracking — entries sync to that Redmine backend.

# Build

One Flutter app for iOS, Android, macOS, Windows, and Linux. Install
[Flutter](https://docs.flutter.dev/get-started/install) (stable; developed against
3.44.3), then from `app/`:

```bash
cd app
flutter pub get
flutter run -d macos        # or windows / linux / a connected device

flutter analyze
flutter test                # the full suite under app/test/
```

Linux desktop needs the GTK build deps: `clang cmake ninja-build pkg-config
libgtk-3-dev liblzma-dev`. macOS/Windows just need the standard Flutter desktop
toolchain (Xcode / Visual Studio "Desktop development with C++").

Release builds and packaged installers (Linux AppImage, macOS `.dmg`, Windows
`setup.exe`) are produced by GitHub Actions in
[`.github/workflows/`](.github/workflows) — `desktop-ci.yml` on every push/PR and
`desktop-release.yml` on a `v*` tag.

# Credits

Redtick is built on **[Toggl Desktop](https://github.com/toggl-open-source/toggldesktop)** by the Toggl team and open-source contributors, used under the **BSD-3-Clause** licence. Huge thanks to them — Redtick changes the backend and branding; the desktop client itself is their work. The original licence is retained in [`LICENSE`](LICENSE).

The Redmine integration and rebrand were authored with **[Claude Code](https://claude.com/claude-code)** (Anthropic).

Redtick is not affiliated with or endorsed by Toggl, Anthropic, or the Redmine project.
