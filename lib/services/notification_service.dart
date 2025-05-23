import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import '../services/settings_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

// Function type definition for notification tap callback
typedef NotificationTapCallback = void Function();
// Function type definition for notification action callback
typedef NotificationActionCallback = void Function(String actionId);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Callback to be called when a notification is tapped
  NotificationTapCallback? _onNotificationTapped;
  // Callback to be called when a notification action is triggered
  NotificationActionCallback? _onNotificationAction;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Audio player for notification sounds
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Timer for recurring notifications
  Timer? _clockInReminderTimer;
  Timer? _clockOutReminderTimer;

  // Notification IDs
  static const int clockInNotificationId = 1;
  static const int clockOutNotificationId = 2;
  static const int clockInCompletedNotificationId = 3;
  static const int clockOutCompletedNotificationId = 4;
  static const int testNotificationId = 999;

  // Action IDs
  static const String clockInActionId = 'CLOCK_IN_ACTION';
  static const String clockOutActionId = 'CLOCK_OUT_ACTION';

  // Set callback for notification taps
  void setOnNotificationTap(NotificationTapCallback callback) {
    _onNotificationTapped = callback;
  }

  // Set callback for notification actions
  void setOnNotificationAction(NotificationActionCallback callback) {
    _onNotificationAction = callback;
  }

  // Play notification sound based on notification type
  Future<void> _playNotificationSound(int notificationId) async {
    try {
      // Check if sound notifications are enabled
      final bool enableSoundNotifications =
          await SettingsService.getEnableSoundNotifications();

      if (enableSoundNotifications) {
        String soundAsset;

        // Select sound based on notification ID
        if (notificationId == clockInNotificationId) {
          // Clock-in notification sound
          soundAsset = 'clock_in_001.wav';
        } else if (notificationId == clockOutNotificationId) {
          // Clock-out notification sound
          soundAsset = 'clock_out_001.wav';
        } else {
          return;
        }

        // Play the selected sound
        await _audioPlayer.play(
          AssetSource(soundAsset),
          mode: PlayerMode.lowLatency,
        );
      }
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
    }
  }

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Register action callbacks for iOS
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
          onDidReceiveLocalNotification:
              (int id, String? title, String? body, String? payload) async {},
          notificationCategories: [
            DarwinNotificationCategory(
              'freee_dakoku_category',
              actions: [
                DarwinNotificationAction.plain(
                  clockInActionId,
                  '出勤',
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  clockOutActionId,
                  '退勤',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
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
        // Bring the app to foreground when notification is tapped or action is performed
        _handleNotificationResponse(notificationResponse);
      },
    );
  }

  // Handle notification taps and action buttons
  void _handleNotificationResponse(NotificationResponse response) {
    debugPrint(
      'Notification response: ${response.notificationResponseType} - ${response.id} - ${response.actionId}',
    );

    // Handle action buttons if pressed
    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotificationAction) {
      if (response.actionId == clockInActionId ||
          response.actionId == clockOutActionId) {
        debugPrint('Action button pressed: ${response.actionId}');

        // Execute the registered action callback
        if (_onNotificationAction != null) {
          _onNotificationAction!(response.actionId!);
        }
        return;
      }
    }

    // Handle regular notification tap
    // テスト通知の場合もコールバックを確実に実行する
    if (response.id == testNotificationId) {
      debugPrint('Test notification tapped, ensuring callback execution');
    }

    // Execute the registered callback
    if (_onNotificationTapped != null) {
      // 直ちに実行
      _onNotificationTapped!();

      // 少し遅延後にも再度実行を試みる（確実に反応させるため）
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_onNotificationTapped != null) {
          _onNotificationTapped!();
        }
      });
    } else {
      debugPrint('Warning: No notification tap callback registered');
    }
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
    bool includeActionClockIn = false,
    bool includeActionClockOut = false,
  }) async {
    // Android notification with actions if requested
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'freee_dakoku_channel',
          'Freee Dakoku Notifications',
          channelDescription: 'Notifications from Freee Dakoku app',
          importance: Importance.max,
          priority: Priority.high,
          actions: _buildAndroidActions(
            includeActionClockIn,
            includeActionClockOut,
          ),
        );

    // iOS notification with category ID for actions if requested
    final DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier:
              (includeActionClockIn || includeActionClockOut)
                  ? 'freee_dakoku_category'
                  : null,
        );

    final LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails(
          actions: _buildLinuxActions(
            includeActionClockIn,
            includeActionClockOut,
          ),
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
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

    // Play notification sound
    await _playNotificationSound(id);
  }

  // Helper method to build Android notification actions based on which actions are enabled
  List<AndroidNotificationAction>? _buildAndroidActions(
    bool includeClockIn,
    bool includeClockOut,
  ) {
    if (!includeClockIn && !includeClockOut) {
      return null;
    }

    final List<AndroidNotificationAction> actions = [];

    if (includeClockIn) {
      actions.add(const AndroidNotificationAction(clockInActionId, '出勤'));
    }

    if (includeClockOut) {
      actions.add(const AndroidNotificationAction(clockOutActionId, '退勤'));
    }

    return actions;
  }

  // Helper method to build Linux notification actions based on which actions are enabled
  List<LinuxNotificationAction> _buildLinuxActions(
    bool includeClockIn,
    bool includeClockOut,
  ) {
    final List<LinuxNotificationAction> actions = [];

    if (includeClockIn) {
      actions.add(LinuxNotificationAction(key: clockInActionId, label: '出勤'));
    }

    if (includeClockOut) {
      actions.add(LinuxNotificationAction(key: clockOutActionId, label: '退勤'));
    }

    return actions;
  }

  // Updated reminder methods to include actions in notifications

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

      // Show the reminder notification with action buttons
      await showNotification(
        id: clockInNotificationId,
        title: '出勤打刻リマインダー',
        body: '出勤打刻がまだ行われていません。打刻を行ってください。',
        includeActionClockIn: true, // Add clock-in action button
      );
    });
  }

  // Start a recurring reminder for clock-out with action buttons
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

        // Show the reminder notification with action buttons
        await showNotification(
          id: clockOutNotificationId,
          title: '退勤打刻リマインダー',
          body: '退勤打刻がまだ行われていません。打刻を行ってください。',
          includeActionClockOut: true, // Add clock-out action button
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

  Future<void> showTestNotification({bool includeActions = false}) async {
    await showNotification(
      id: testNotificationId,
      title: 'テスト通知',
      body: 'これはテスト通知です。通知システムが正常に動作しています。',
      includeActionClockIn: includeActions,
      includeActionClockOut: includeActions,
    );
  }
}
