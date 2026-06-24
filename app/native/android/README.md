# Android build (FP-11)

Builds the C++ core (`../../../src`) into `libTogglDesktopLibrary.so` for Android
ABIs, linking statically-cross-compiled OpenSSL 3, Poco and jsoncpp. Gradle's
`externalNativeBuild` then compiles it per ABI and packages the `.so` into the APK;
the app loads it with `DynamicLibrary.open('libTogglDesktopLibrary.so')`.

## ⚠️ Environment note

This was authored where the **Android NDK/SDK could not be installed**: the only
distribution host (`dl.google.com` / `maven.google.com`) is blocked by the
sandbox network policy (HTTP 403), and no mirror is reachable. The build
configuration and scripts below are therefore **authored but not executed here**.
They are ready to run in any environment where the NDK and Google Maven are
reachable (local dev, normal CI).

## Prerequisites

- Android SDK + NDK r25+ (`ANDROID_NDK_HOME`), CMake, Ninja.
- The Flutter Android toolchain (`flutter doctor` green for Android).

## Steps

```bash
# 1. Cross-build the native deps per ABI → native/android/.deps-prefix/<abi>/
cd app/native/android
export ANDROID_NDK_HOME=~/Android/Sdk/ndk/<version>
for abi in arm64-v8a armeabi-v7a x86_64; do ./build-deps.sh "$abi"; done

# 2. Build the app — Gradle's externalNativeBuild compiles the core per ABI
#    (it passes -DREDTICK_DEPS_ROOT=<.deps-prefix> automatically) and bundles
#    each libTogglDesktopLibrary.so into the APK.
cd ../../..        # repo root/app
flutter build apk --debug         # or: flutter build appbundle
```

## What was adapted for Android

- `app/native/CMakeLists.txt`: discovers OpenSSL/Poco/jsoncpp from the per-ABI
  prefix (`REDTICK_DEPS_ROOT`) instead of system packages.
- `android/app/build.gradle.kts`: `externalNativeBuild` → `native/CMakeLists.txt`,
  `abiFilters`, `minSdk ≥ 24`.
- Core source guards (desktop behaviour unchanged):
  - `src/platforminfo.{h,cc}` — X11 OS-detection is excluded on `__ANDROID__`
    (inline no-op), since Android has no X11.
  - `get_focused_window_android.cc` — no-op stub (Android sandboxing forbids
    inspecting other apps' windows); autotracker window detection is desktop-only.

## Follow-ups

- libc++: the core is C++17; ensure `ANDROID_STL=c++_shared` and that
  `libc++_shared.so` is packaged (NDK/AGP default). Switch to `c++_static` only if
  no other native lib in the app uses the STL.
- Idle/timeline (FP-52/53) are desktop-only and remain no-ops on Android.
- Verify a login round-trip against a Redmine backend on a device/emulator
  (online half of FP-13).
