import 'dart:async';

/// Counts user-attributable in-flight Redmine requests and exposes a
/// flicker-smoothed busy signal for the global activity indicator.
///
/// Requests started while [runBackground] is active (30 s poll, app-resume
/// silent refresh) are not counted, so the indicator only reflects traffic
/// that follows a user action. Known edge: a user request that starts during
/// an in-flight silent-poll window is classified as background and misses one
/// pulse — rare and self-healing.
class NetworkActivityTracker {
  NetworkActivityTracker({
    this.showDelay = const Duration(milliseconds: 150),
    this.minShow = const Duration(milliseconds: 350),
  });

  /// Continuous activity required before [busy] turns true — fast requests
  /// never flash the indicator.
  final Duration showDelay;

  /// Minimum time [busy] stays true once shown, to avoid flicker.
  final Duration minShow;

  int _active = 0;
  int _bgDepth = 0;
  bool _visible = false;
  bool _minShowSatisfied = false;
  bool _hidePending = false;
  Timer? _showTimer;
  Timer? _minShowTimer;

  final _count = StreamController<int>.broadcast();
  final _busy = StreamController<bool>.broadcast();

  /// Raw count of user-attributable requests in flight.
  Stream<int> get activeRequests => _count.stream;

  /// Smoothed "show the indicator" flag.
  Stream<bool> get busy => _busy.stream;

  /// Current smoothed value, for seeding late subscribers.
  bool get busyNow => _visible;

  /// Current raw count.
  int get active => _active;

  /// Runs one HTTP request, counting it unless a background bracket is
  /// active. The classification is captured at start so the decrement always
  /// matches the increment, even if the bracket ends mid-request.
  Future<T> track<T>(Future<T> Function() op) async {
    final counted = _bgDepth == 0;
    if (counted) _change(1);
    try {
      return await op();
    } finally {
      if (counted) _change(-1);
    }
  }

  /// Brackets a background flow so its requests don't pulse the indicator.
  Future<T> runBackground<T>(Future<T> Function() op) async {
    _bgDepth++;
    try {
      return await op();
    } finally {
      _bgDepth--;
    }
  }

  void _change(int delta) {
    _active += delta;
    _count.add(_active);
    if (_active > 0) {
      _hidePending = false;
      if (!_visible && _showTimer == null) {
        _showTimer = Timer(showDelay, () {
          _showTimer = null;
          if (_active == 0) return;
          _visible = true;
          _minShowSatisfied = false;
          _busy.add(true);
          _minShowTimer = Timer(minShow, () {
            _minShowSatisfied = true;
            if (_hidePending && _active == 0) _hide();
          });
        });
      }
    } else {
      _showTimer?.cancel();
      _showTimer = null;
      if (_visible) {
        if (_minShowSatisfied) {
          _hide();
        } else {
          _hidePending = true;
        }
      }
    }
  }

  void _hide() {
    _visible = false;
    _hidePending = false;
    _busy.add(false);
  }

  void dispose() {
    _showTimer?.cancel();
    _minShowTimer?.cancel();
    _count.close();
    _busy.close();
  }
}
