import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'idle_log.dart';

/// Desktop window control (idle bring-to-front). Raises redtick's own window via
/// the `redtick/window` platform channel (implemented in each desktop Runner) so
/// the user sees the "You've been idle" prompt when they return. No-op where
/// unsupported, so callers stay platform-agnostic. Mirrors [IdleDetector].
class AppWindow {
  static const _ch = MethodChannel('redtick/window');

  static bool get supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Best-effort raise-to-foreground. Fire-and-forget: never throws, so callers
  /// (e.g. the idle prompt) needn't guard it. The OS may refuse focus theft
  /// (Win32 background restriction, Wayland) — that's logged, not surfaced.
  static Future<void> foreground() async {
    if (!supported) return;
    try {
      final raised = await _ch.invokeMethod<bool>('foreground');
      idleLog('native window.foreground -> raised=$raised');
    } catch (e, st) {
      // Mirror IdleDetector.seconds(): a MissingPluginException or any channel
      // error must be observable, not silent.
      idleLog('native window.foreground FAILED: $e\n$st');
    }
  }

  /// Pin (`on: true`) or release (`on: false`) the window above other apps'
  /// windows. [foreground] alone is unreliable on macOS 14+, whose cooperative
  /// `NSApp.activate()` often won't pull us over the frontmost app, and a normal
  /// window level doesn't float — so while the idle prompt awaits an answer we
  /// raise the window level / topmost flag to make it unmissable, then drop back
  /// to normal once answered. Best-effort and fire-and-forget like [foreground].
  static Future<void> setAlwaysOnTop(bool on) async {
    if (!supported) return;
    try {
      final ok = await _ch.invokeMethod<bool>('setAlwaysOnTop', {'on': on});
      idleLog('native window.setAlwaysOnTop($on) -> ok=$ok');
    } catch (e, st) {
      idleLog('native window.setAlwaysOnTop($on) FAILED: $e\n$st');
    }
  }
}
