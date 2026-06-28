#!/usr/bin/env bash
# Android release smoke test: install the release APK on a booted emulator, launch
# it, and fail if it crashes at startup (FATAL EXCEPTION or a dead process). This
# catches release-only crashes (e.g. R8 stripping WorkManager) that a build can't.
# Run from app/ by android-ci.yml's emulator step. Kept as a file because
# android-emulator-runner runs each inline `script:` line in a separate shell.
set -u

APK="build/app/outputs/flutter-apk/app-release.apk"
PKG="cz.syky.redtick.redtick"

echo "Installing $APK"
adb install -r "$APK" || { echo "::error::adb install failed"; exit 1; }
adb logcat -c
adb shell am start -n "$PKG/.MainActivity"

# Watch ~30s: fail fast on a FATAL EXCEPTION; otherwise require the process to be
# alive at the end (a startup crash leaves it dead).
i=0
while [ "$i" -lt 30 ]; do
  if adb logcat -d | grep -q "FATAL EXCEPTION"; then
    echo "::error::FATAL EXCEPTION after launch — release-mode startup crash."
    adb logcat -d | grep -A40 "FATAL EXCEPTION" | head -60
    exit 1
  fi
  i=$((i + 1))
  sleep 1
done

PID="$(adb shell pidof "$PKG" | tr -d '[:space:]')"
if [ -z "$PID" ]; then
  echo "::error::App not running ~30s after launch — release-mode startup crash."
  adb logcat -d -t 500 | grep -iE "FATAL|AndroidRuntime|E flutter|Exception|InitializationProvider|redtick" | tail -60 || true
  exit 1
fi

echo "Smoke test passed: $PKG launched (pid $PID) and stayed alive."
