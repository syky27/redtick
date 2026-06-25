import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desktop idle-detection settings: an on/off toggle and a configurable
/// threshold in minutes, persisted with shared_preferences. Mirrors the Qt
/// app's `use_idle_detection` + `idle_minutes` (defaults: on, 5 min, min 1).
/// Read by [IdleWatcher]; the UI exposes it only on desktop platforms.
class IdleSettings {
  const IdleSettings({this.enabled = true, this.minutes = 5});
  final bool enabled;
  final int minutes;

  IdleSettings copyWith({bool? enabled, int? minutes}) => IdleSettings(
        enabled: enabled ?? this.enabled,
        minutes: minutes ?? this.minutes,
      );
}

class IdleSettingsNotifier extends Notifier<IdleSettings> {
  static const _kEnabled = 'idle_detection_enabled';
  static const _kMinutes = 'idle_minutes';

  @override
  IdleSettings build() {
    _load();
    return const IdleSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = IdleSettings(
      enabled: prefs.getBool(_kEnabled) ?? true,
      minutes: clampMinutes(prefs.getInt(_kMinutes) ?? 5),
    );
  }

  Future<void> setEnabled(bool v) async {
    state = state.copyWith(enabled: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, v);
  }

  Future<void> setMinutes(int v) async {
    final m = clampMinutes(v);
    state = state.copyWith(minutes: m);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMinutes, m);
  }

  /// Qt enforces a 1-minute floor; the UI uses a 3-digit field (≤ 999).
  static int clampMinutes(int v) => v < 1 ? 1 : (v > 999 ? 999 : v);
}

final idleSettingsProvider =
    NotifierProvider<IdleSettingsNotifier, IdleSettings>(
        IdleSettingsNotifier.new);
