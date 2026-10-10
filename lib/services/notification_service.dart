import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool get isInitialized => _initialized;

  static const AndroidNotificationChannel _careChannel =
      AndroidNotificationChannel(
        'urban_farming_care',
        'Plant Care Reminders',
        description: 'Reminders for watering and other plant-care tasks.',
        importance: Importance.high,
      );

  /// Initializes local notifications once.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const settings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidPlugin?.createNotificationChannel(_careChannel);

      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('Notification initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Care notification tapped: ${response.payload ?? ''}');
  }

  /// Requests notification permission on Android 13 and newer.
  Future<bool> requestPermission() async {
    await initialize();

    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin == null) return false;

      return await androidPlugin.requestNotificationsPermission() ?? false;
    } catch (error, stackTrace) {
      debugPrint('Notification permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Displays a notification immediately.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'urban_farming_care',
        'Plant Care Reminders',
        channelDescription:
            'Reminders for watering and other plant-care tasks.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Schedules a one-time reminder.
  ///
  /// The timezone package must be configured with the device's actual
  /// timezone before relying on local reminder times.
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await initialize();

    if (!scheduledDate.isAfter(DateTime.now())) {
      debugPrint('Reminder not scheduled because its time has passed.');
      return;
    }

    final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'urban_farming_care',
        'Plant Care Reminders',
        channelDescription:
            'Reminders for watering and other plant-care tasks.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Cancels one scheduled reminder.
  Future<void> cancelReminder(int id) async {
    await initialize();
    await _plugin.cancel(id);
  }

  /// Cancels all notifications managed by this service.
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  /// Creates a stable positive notification ID from a task document ID.
  int notificationIdForTask(String taskId) {
    var hash = 0x811c9dc5;

    for (final unit in taskId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }

    return hash == 0 ? 1 : hash;
  }
}
