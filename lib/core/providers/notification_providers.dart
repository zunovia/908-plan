import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notification_service.dart';

/// Overridden in main() with an initialized instance.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
