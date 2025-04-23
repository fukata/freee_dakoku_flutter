import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import '../services/settings_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Timer for recurring notifications
  Timer? _clockInReminderTimer;
  Timer? _clockOutReminderTimer;

  // Notification IDs
  static const int clockInNotificationId = 1;
  static const int clockOutNotificationId = 2;
  static const int testNotificationId = 999;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
          onDidReceiveLocalNotification:
              (int id, String? title, String? body, String? payload) async {},
        );
    final LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
          linux: initializationSettingsLinux,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (
        NotificationResponse notificationResponse,
      ) {
        // Handle notification taps here
      },
    );
  }

  Future<void> requestPermissions() async {
    // Request iOS permissions
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Request macOS permissions
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'freee_dakoku_channel',
          'Freee Dakoku Notifications',
          channelDescription: 'Notifications from Freee Dakoku app',
          importance: Importance.max,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
      linux: linuxPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Start a recurring reminder for clock-in
  Future<void> startClockInReminder() async {
    // Cancel any existing reminder first
    cancelClockInReminder();

    final bool enableNotifications =
        await SettingsService.getEnableNotifications();
    if (!enableNotifications) return;

    final int intervalMinutes = await SettingsService.getNotificationInterval();

    _clockInReminderTimer = Timer.periodic(Duration(minutes: intervalMinutes), (
      timer,
    ) async {
      // Check if notifications are still enabled
      final bool stillEnabled = await SettingsService.getEnableNotifications();
      if (!stillEnabled) {
        cancelClockInReminder();
        return;
      }

      // Show the reminder notification
      await showNotification(
        id: clockInNotificationId,
        title: '出勤打刻リマインダー',
        body: '出勤打刻がまだ行われていません。打刻を行ってください。',
      );
    });
  }

  // Start a recurring reminder for clock-out
  Future<void> startClockOutReminder() async {
    // Cancel any existing reminder first
    cancelClockOutReminder();

    final bool enableNotifications =
        await SettingsService.getEnableNotifications();
    if (!enableNotifications) return;

    final int intervalMinutes = await SettingsService.getNotificationInterval();

    _clockOutReminderTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (timer) async {
        // Check if notifications are still enabled
        final bool stillEnabled =
            await SettingsService.getEnableNotifications();
        if (!stillEnabled) {
          cancelClockOutReminder();
          return;
        }

        // Show the reminder notification
        await showNotification(
          id: clockOutNotificationId,
          title: '退勤打刻リマインダー',
          body: '退勤打刻がまだ行われていません。打刻を行ってください。',
        );
      },
    );
  }

  // Cancel clock-in reminder
  void cancelClockInReminder() {
    _clockInReminderTimer?.cancel();
    _clockInReminderTimer = null;
  }

  // Cancel clock-out reminder
  void cancelClockOutReminder() {
    _clockOutReminderTimer?.cancel();
    _clockOutReminderTimer = null;
  }

  Future<void> showTestNotification() async {
    await showNotification(
      id: testNotificationId,
      title: 'テスト通知',
      body: 'これはテスト通知です。通知システムが正常に動作しています。',
    );
  }
}
