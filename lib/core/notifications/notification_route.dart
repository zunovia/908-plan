import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Route requested by a tapped notification (e.g. '/release/write').
///
/// The notification layer sets it; the router listener in app.dart navigates
/// there once and then resets it to null.
final notificationRouteProvider = StateProvider<String?>((ref) => null);

/// Drops a route delivered twice in a short time (a cold start can report the
/// same tap through both the launch details and the response callback).
class NotificationRouteDeduper {
  NotificationRouteDeduper({DateTime Function()? clock, this.window = const Duration(seconds: 3)})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration window;
  String? _last;
  DateTime? _lastAt;

  /// True when [route] should be delivered.
  bool accept(String route) {
    final now = _clock();
    final lastAt = _lastAt;
    if (_last == route && lastAt != null && now.difference(lastAt) < window) {
      return false;
    }
    _last = route;
    _lastAt = now;
    return true;
  }
}
