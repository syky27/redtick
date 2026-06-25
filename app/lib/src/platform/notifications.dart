import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Presents reminder/pomodoro notices from the app (FP-54) and the
/// "running but not tracking" reminder.
///
/// The real presenter ([_LocalNotificationPresenter]) delivers an OS-level
/// notification via `flutter_local_notifications`, so it surfaces even when the
/// window is unfocused or in the background. The UI *also* shows an in-app
/// banner for every notice, so when the OS notification is unavailable (e.g. an
/// unsigned macOS dev build, or permission denied) the user still sees it. Any
/// plugin failure degrades silently to logging — never crashes the app.
abstract class NotificationPresenter {
  void show(String title, String body);

  /// The default presenter for the running platform.
  factory NotificationPresenter.defaultFor() {
    // flutter_local_notifications supports these platforms; Windows + others
    // fall back to logging (the in-app banner remains the visible cue).
    if (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isLinux) {
      return _LocalNotificationPresenter();
    }
    return _LoggingPresenter();
  }
}

/// Delivers real OS notifications. Initialises lazily on first [show] (which
/// requests permission on macOS/iOS) and falls back to logging on any error.
class _LocalNotificationPresenter implements NotificationPresenter {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;
  bool _failed = false;
  int _id = 0;

  Future<void> _ensureInit() async {
    if (_inited || _failed) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
    );
    await _plugin.initialize(settings: settings);
    _inited = true;
  }

  @override
  void show(String title, String body) {
    // Fire-and-forget: the interface is synchronous, but delivery is async.
    () async {
      try {
        await _ensureInit();
        const android = AndroidNotificationDetails(
          'redtick_reminders',
          'Reminders',
          channelDescription: 'Idle and "track your time" reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );
        const details = NotificationDetails(
          android: android,
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
          linux: LinuxNotificationDetails(),
        );
        await _plugin.show(
          id: _id++,
          title: title,
          body: body,
          notificationDetails: details,
        );
      } catch (e) {
        _failed = true; // stop retrying init/show; rely on the in-app banner
        debugPrint('[notification:fallback] $title — $body ($e)');
      }
    }();
  }
}

class _LoggingPresenter implements NotificationPresenter {
  @override
  void show(String title, String body) {
    debugPrint('[notification] $title — $body');
  }
}
