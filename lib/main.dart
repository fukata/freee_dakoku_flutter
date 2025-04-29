import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'screens/oauth_settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/app_settings_screen.dart';
import 'utils/reminder_utils.dart'; // Import the new utility
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:holiday_jp/holiday_jp.dart' as HolidayJp;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window_manager for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      await windowManager.ensureInitialized();

      WindowOptions windowOptions = const WindowOptions(
        size: Size(500, 700),
        center: true,
        title: 'freee打刻アプリ',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      // Handle exception for mobile platforms or if window_manager isn't available
      debugPrint('Window manager initialization failed: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'freee打刻アプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'freee打刻アプリ'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = true;
  bool _isConfigured = false;
  bool _isLoggedIn = false;
  UserInfo? _userInfo;
  HrCompanyInfo? _selectedCompany; // 選択中の事業所
  final NotificationService _notificationService = NotificationService();
  DateTime _currentDateTime = DateTime.now();
  Timer? _timer;
  Timer? _workScheduleCheckTimer;

  // 就業時間の設定
  String _startWorkTime = '09:00';
  String _endWorkTime = '18:00';
  bool _enableNotifications = true;

  // 打刻ボタンの状態
  bool _canClockIn = false;
  bool _canClockOut = false;
  List<TimeClock>? _timeClocks;
  bool _isClockActionLoading = false;

  // 以前の設定値を保存する変数
  String _previousStartWorkTime = '09:00';
  String _previousEndWorkTime = '18:00';
  bool _previousEnableNotifications = true;

  @override
  void initState() {
    super.initState();
    // Initialize the app and set up timers
    () async {
      await _initializeApp();
      _setupTimers();

      await _checkSettingsChanges();
      // 毎分、打刻状態と通知の必要性をチェック
      await _checkWorkScheduleAndNotifications();
    }();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _workScheduleCheckTimer?.cancel();
    _notificationService.cancelClockInReminder();
    _notificationService.cancelClockOutReminder();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _notificationService.init();

    // Set up notification tap handler
    _notificationService.setOnNotificationTap(() {
      // This will bring the app to the foreground when notification is tapped
      _bringAppToForeground();
    });

    // Set up handler for notification action buttons
    _notificationService.setOnNotificationAction((String actionId) {
      if (actionId == NotificationService.clockInActionId) {
        debugPrint('Handling clock-in action from notification');
        // Check if we can clock in and do it
        if (_canClockIn && !_isClockActionLoading) {
          _clockIn();
        } else {
          debugPrint(
            'Cannot clock in right now: enabled=$_canClockIn, loading=$_isClockActionLoading',
          );
        }
      } else if (actionId == NotificationService.clockOutActionId) {
        debugPrint('Handling clock-out action from notification');
        // Check if we can clock out and do it
        if (_canClockOut && !_isClockActionLoading) {
          _clockOut();
        } else {
          debugPrint(
            'Cannot clock out right now: enabled=$_canClockOut, loading=$_isClockActionLoading',
          );
        }
      }
    });

    await _loadWorkScheduleSettings();
    await _checkSettings();
  }

  // タイマーのセットアップを行う
  void _setupTimers() {
    // 既存のタイマーがあればキャンセル
    _timer?.cancel();
    _workScheduleCheckTimer?.cancel();

    // 時間表示を更新するタイマーを設定（1分ごと）
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        _currentDateTime = DateTime.now();
      });
      _checkSettingsChanges();
      // 毎分、打刻状態と通知の必要性をチェック
      _checkWorkScheduleAndNotifications();
    });

    // 打刻情報を更新するタイマー（5分ごと）
    _workScheduleCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isLoggedIn) {
        _fetchLatestTimeClocks();
      }
    });
  }

  // 設定の変更をチェックし、変更があればタイマーをリセット
  Future<void> _checkSettingsChanges() async {
    await _loadWorkScheduleSettings();

    // 設定値が変更されているかチェック
    bool settingsChanged =
        _startWorkTime != _previousStartWorkTime ||
        _endWorkTime != _previousEndWorkTime ||
        _enableNotifications != _previousEnableNotifications;

    // 設定が変更されていれば現在値を保存してタイマーをリセット
    if (settingsChanged) {
      debugPrint('Work schedule settings changed, resetting timers');

      // 前回の値を更新
      _previousStartWorkTime = _startWorkTime;
      _previousEndWorkTime = _endWorkTime;
      _previousEnableNotifications = _enableNotifications;

      // 通知リマインダーをリセット
      _notificationService.cancelClockInReminder();
      _notificationService.cancelClockOutReminder();

      // タイマーを再設定
      _setupTimers();

      // 設定変更後すぐに状態をチェック
      _checkWorkScheduleAndNotifications();
    }
  }

  // Bring the app to the foreground when notification is tapped
  void _bringAppToForeground() {
    debugPrint('Bringing app to foreground after notification tap');

    // ユニークなメッセージチャネルを設定して、アプリをフォアグラウンドに戻す
    const platform = MethodChannel('com.example.freee_dakoku/app_retain');

    try {
      platform
          .invokeMethod('bringToForeground')
          .then((_) {
            debugPrint(
              'Successfully called native method to bring app to foreground',
            );
          })
          .catchError((error) {
            debugPrint('Error bringing app to foreground: $error');
          });
    } catch (e) {
      debugPrint('Exception when bringing app to foreground: $e');
    }

    // 遅延をかけてからナビゲーションを実行
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });
  }

  Future<void> _loadWorkScheduleSettings() async {
    final startTime = await SettingsService.getStartWorkTime();
    final endTime = await SettingsService.getEndWorkTime();
    final enableNotifications = await SettingsService.getEnableNotifications();

    setState(() {
      _startWorkTime = startTime;
      _endWorkTime = endTime;
      _enableNotifications = enableNotifications;
    });
  }

  Future<void> _checkSettings() async {
    final isConfigured = await SettingsService.isOAuthConfigured();
    final isLoggedIn =
        isConfigured ? await SettingsService.isLoggedIn() : false;

    if (isLoggedIn) {
      // ログイン済みの場合はユーザー情報を取得
      final userInfo = await SettingsService.getFullUserInfo();

      setState(() {
        _isConfigured = isConfigured;
        _isLoggedIn = isLoggedIn;
        _userInfo = userInfo;
      });

      // ユーザー情報を設定した後に事業所選択を初期化する
      await _initializeCompanySelection();

      // 事業所選択後に最新の打刻情報を取得
      await _fetchLatestTimeClocks();

      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _isConfigured = isConfigured;
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
    }

    if (!isConfigured) {
      _showSettingsScreen();
    } else if (!isLoggedIn) {
      _showLoginScreen();
    }
  }

  Future<void> _fetchLatestTimeClocks() async {
    try {
      // 選択された事業所を引数として渡す
      final timeClocks = await SettingsService.getLatestTimeClocks(
        selectedCompany: _selectedCompany,
      );

      if (timeClocks == null) {
        setState(() {
          _timeClocks = [];
          // データが取得できない場合は出勤ボタンのみ活性化
          _canClockIn = true;
          _canClockOut = false;
        });
        return;
      }

      setState(() {
        _timeClocks = timeClocks;

        if (timeClocks.isEmpty) {
          // データがない場合は出勤ボタンのみ活性化
          _canClockIn = true;
          _canClockOut = false;
        } else {
          // 最後の打刻のタイプをチェック
          final lastTimeClock = timeClocks.last;

          if (lastTimeClock.type == 'clock_in') {
            // 最後の打刻が出勤の場合は退勤ボタンを活性化
            _canClockIn = false;
            _canClockOut = true;
          } else if (lastTimeClock.type == 'clock_out') {
            // 最後の打刻が退勤の場合は出勤ボタンを活性化
            _canClockIn = true;
            _canClockOut = false;
          } else {
            // その他の場合（休憩など）は一旦両方活性化
            _canClockIn = true;
            _canClockOut = true;
          }
        }
      });
    } catch (e) {
      debugPrint('Error fetching time clocks: $e');
      setState(() {
        _timeClocks = [];
        _canClockIn = true;
        _canClockOut = false;
      });
    }
  }

  Future<void> _showSettingsScreen() async {
    if (!mounted) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const OAuthSettingsScreen()),
    );

    if (result == true) {
      _checkSettings();
    }
  }

  Future<void> _showLoginScreen() async {
    if (!mounted) return;

    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const LoginScreen()));

    if (result == true) {
      _checkSettings();
    }
  }

  void _openSettings() {
    _showSettingsScreen();
  }

  void _logout() async {
    await SettingsService.logout();
    _checkSettings();
  }

  void _viewUserProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const UserProfileScreen()));
  }

  void _showAppSettings() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AppSettingsScreen()));

    // Check if settings were changed
    if (result is Map<String, bool>) {
      bool workScheduleChanged =
          result['startTimeChanged'] == true ||
          result['endTimeChanged'] == true;
      bool notificationsChanged = result['notificationsChanged'] == true;

      if (workScheduleChanged || notificationsChanged) {
        debugPrint(
          'Work schedule or notification settings changed, refreshing...',
        );

        // 設定を再取得し、タイマーをリセット
        await _loadWorkScheduleSettings();

        // 設定の変更を検出したら即座にタイマーをリセットして通知の設定を反映
        _notificationService.cancelClockInReminder();
        _notificationService.cancelClockOutReminder();
        _setupTimers();

        // 打刻状態と通知の必要性をすぐにチェック
        _checkWorkScheduleAndNotifications();
      }
    }
  }

  void _openFreeeWebsite() async {
    const url = 'https://p.secure.freee.co.jp/';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  // 土日かどうかを判定する
  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday || _isHoliday(date);
  }

  // 日本の祝日かどうかを判定する
  bool _isHoliday(DateTime date) {
    return HolidayJp.isHoliday(date);
  }

  // 仕事の予定と通知の必要性をチェック
  Future<void> _checkWorkScheduleAndNotifications() async {
    if (!_isLoggedIn || !_enableNotifications) return;

    final now = DateTime.now();

    // 土日の場合は通知をスキップ
    if (_isWeekend(now)) {
      debugPrint('Skipping notifications on weekend');
      return;
    }

    // 勤務開始時間と終了時間を解析
    final startTimeParts = _startWorkTime.split(':');
    final startHour = int.parse(startTimeParts[0]);
    final startMinute = int.parse(startTimeParts[1]);

    final endTimeParts = _endWorkTime.split(':');
    final endHour = int.parse(endTimeParts[0]);
    final endMinute = int.parse(endTimeParts[1]);

    // 今日の勤務開始・終了時刻を作成
    final startDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      startHour,
      startMinute,
    );
    final endDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      endHour,
      endMinute,
    );

    // 現在の打刻状態を確認
    bool hasCheckedIn = false;
    bool hasCheckedOut = false;

    if (_timeClocks != null && _timeClocks!.isNotEmpty) {
      final lastTimeClock = _timeClocks!.last;
      final lastTimeClockDateTime = lastTimeClock.dateTime!.toLocal();
      debugPrint('lastTimeClockDateTime:: $lastTimeClockDateTime, now: ${now}');


      // 最後の打刻のタイプを確認
      if (lastTimeClock.type == 'clock_in') {
        hasCheckedIn = true;
      } else if (lastTimeClock.type == 'clock_out') {
        if (ReminderUtils.isSkipReminder(lastTimeClockDateTime, now)) {
          debugPrint('Skipping reminder: lastTimeClockDateTime is today');
          return;
        }

        hasCheckedOut = true;
      }
    }

    debugPrint('hasCheckedIn: $hasCheckedIn, hasCheckedOut: $hasCheckedOut, startDateTime: $startDateTime, endDateTime: $endDateTime');

    // 出勤時刻を過ぎているのに打刻がない場合
    final isNeedNotifyForClockIn = ReminderUtils.isNeedNotifyForClockIn(
      now: now,
      startDateTime: startDateTime,
      hasCheckedIn: hasCheckedIn
    );
    if (isNeedNotifyForClockIn) {
      // 最初の通知 (出勤アクション付き)
      await _notificationService.showNotification(
        id: NotificationService.clockInNotificationId,
        title: '出勤打刻リマインダー',
        body: '出勤時間を過ぎています。出勤打刻を行ってください。',
        includeActionClockIn: true, // 出勤アクションを含める
        includeActionClockOut: false, // 退勤アクションは含めない
      );

      // 定期的なリマインダーを開始
      _notificationService.startClockInReminder();
    } else if (hasCheckedIn) {
      // 出勤打刻済みならリマインダーを停止
      _notificationService.cancelClockInReminder();
    }

    // 退勤時刻を過ぎているのに出勤中の場合（退勤打刻がない）
    final isNeedNotifyForClockOut = ReminderUtils.isNeedNotifyForClockOut(
      now: now,
      endDateTime: endDateTime,
      hasCheckedIn: hasCheckedIn,
      hasCheckedOut: hasCheckedOut
    );
    if (isNeedNotifyForClockOut) {
      // 最初の通知 (退勤アクション付き)
      await _notificationService.showNotification(
        id: NotificationService.clockOutNotificationId,
        title: '退勤打刻リマインダー',
        body: '終業時間を過ぎています。退勤打刻を行ってください。',
        includeActionClockIn: false, // 出勤アクションは含めない
        includeActionClockOut: true, // 退勤アクションを含める
      );

      // 定期的なリマインダーを開始
      _notificationService.startClockOutReminder();
    } else if (hasCheckedOut) {
      // 退勤打刻済みならリマインダーを停止
      _notificationService.cancelClockOutReminder();
    }
  }

  // 事業所を選択する
  Future<void> _selectCompany(HrCompanyInfo? company) async {
    setState(() {
      _selectedCompany = company;
    });

    // 選択された事業所に応じてデータを再読み込み
    if (company != null) {
      debugPrint('Company switched to: ${company.name}');

      // 選択した事業所IDを保存
      await SettingsService.saveSelectedCompanyId(company.id);
    }
  }

  // 初期の事業所選択を行う
  Future<void> _initializeCompanySelection() async {
    if (_userInfo?.hr != null &&
        _userInfo!.hr!.companies.isNotEmpty &&
        _selectedCompany == null) {
      // 保存された事業所IDを取得
      final savedCompanyId = await SettingsService.getSelectedCompanyId();

      if (savedCompanyId != null) {
        // 保存された事業所IDに一致する事業所を探す
        final savedCompany = _userInfo!.hr!.companies.firstWhere(
          (company) => company.id == savedCompanyId,
          orElse: () => _userInfo!.hr!.companies.first, // 見つからない場合は最初の事業所
        );

        // 保存されていた事業所を選択
        _selectCompany(savedCompany);
        debugPrint('Loaded saved company: ${savedCompany.name}');
      } else {
        // 保存された事業所IDがない場合は最初の事業所を選択
        _selectCompany(_userInfo!.hr!.companies.first);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'oauth') {
                _openSettings();
              } else if (value == 'app') {
                _showAppSettings();
              } else if (value == 'logout' && _isLoggedIn) {
                _logout();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'app',
                    child: Row(
                      children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('アプリ設定'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'oauth',
                    child: Row(
                      children: [
                        Icon(Icons.key),
                        SizedBox(width: 8),
                        Text('OAuth設定'),
                      ],
                    ),
                  ),
                  if (_isLoggedIn)
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout),
                          SizedBox(width: 8),
                          Text('ログアウト'),
                        ],
                      ),
                    ),
                ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isConfigured
              ? _isLoggedIn
                  ? _buildMainContent()
                  : _buildLoginNeededContent()
              : _buildConfigurationNeededContent(),
    );
  }

  Widget _buildMainContent() {
    // Format date and time
    final now = _currentDateTime;
    final dateStr =
        '${now.year}年${now.month}月${now.day}日 (${_getWeekdayName(now.weekday)})';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Column(
      children: [
        // User profile section at the top
        if (_userInfo != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        _getInitials(_userInfo!.displayName),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userInfo!.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _userInfo!.email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 事業所選択ドロップダウン
                if (_userInfo?.hr != null &&
                    _userInfo!.hr!.companies.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<HrCompanyInfo>(
                      value: _selectedCompany,
                      isExpanded: true,
                      underline: Container(), // 下線を削除
                      hint: const Text('事業所を選択'),
                      items:
                          _userInfo!.hr!.companies.map((company) {
                            return DropdownMenuItem<HrCompanyInfo>(
                              value: company,
                              child: Text(company.name),
                            );
                          }).toList(),
                      onChanged: (HrCompanyInfo? newValue) async {
                        await _selectCompany(newValue);

                        // 最新の打刻情報を再取得
                        await _fetchLatestTimeClocks();

                        // 打刻状態と通知の必要性をチェック
                        await _checkWorkScheduleAndNotifications();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
        ],

        // Date and time display
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Date
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Current time in larger font
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 60),

                // Clock-in and clock-out buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttendanceButton(
                      label: '出勤',
                      color: Colors.green,
                      icon: Icons.login,
                      onPressed: _clockIn,
                    ),
                    _buildAttendanceButton(
                      label: '退勤',
                      color: Colors.blue,
                      icon: Icons.logout,
                      onPressed: _clockOut,
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Button to open freee website
                ElevatedButton.icon(
                  onPressed: _openFreeeWebsite,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('freeeウェブサイトを開く'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    // Determine if this button is enabled based on label
    bool isEnabled = label == '出勤' ? _canClockIn : _canClockOut;
    bool isLoading = _isClockActionLoading;

    return Column(
      children: [
        ElevatedButton(
          onPressed: isEnabled && !isLoading ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? color : Colors.grey.shade300,
            foregroundColor: isEnabled ? Colors.white : Colors.grey.shade600,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(24),
          ),
          child:
              isLoading
                  ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                  : Icon(icon, size: 40),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isEnabled ? null : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return weekdays[weekday - 1];
  }

  void _clockIn() async {
    if (!_canClockIn || _isClockActionLoading) return;

    setState(() {
      _isClockActionLoading = true;
    });

    try {
      final clockInDate =
          _currentDateTime.toIso8601String().split('T').first; // yyyy-mm-dd
      final clockInDatetime =
          '${_currentDateTime.toIso8601String().split('T').join(' ').split('.').first}'; // yyyy-mm-dd hh:mm:ss
      final success = await SettingsService.clockIn(
        selectedCompany: _selectedCompany!,
        baseDate: clockInDate,
        datetime: clockInDatetime,
      );

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('出勤打刻しました')));

        // 通知を送信
        await _notificationService.showNotification(
          id: NotificationService.clockInCompletedNotificationId,
          title: '出勤打刻',
          body: '${_currentDateTime.hour}時${_currentDateTime.minute}分に出勤打刻しました',
        );

        // 最新の打刻情報を再取得
        await _fetchLatestTimeClocks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('出勤打刻に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Clock in error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isClockActionLoading = false;
      });
    }
  }

  void _clockOut() async {
    if (!_canClockOut || _isClockActionLoading) return;

    setState(() {
      _isClockActionLoading = true;
    });

    try {
      final clockOutDate =
          _currentDateTime.toIso8601String().split('T').first; // yyyy-mm-dd
      final clockOutDatetime =
          '${_currentDateTime.toIso8601String().split('T').join(' ').split('.').first}'; // yyyy-mm-dd hh:mm:ss
      final success = await SettingsService.clockOut(
        selectedCompany: _selectedCompany!,
        baseDate: clockOutDate,
        datetime: clockOutDatetime,
      );

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('退勤打刻しました')));

        // 通知を送信
        await _notificationService.showNotification(
          id: NotificationService.clockOutCompletedNotificationId,
          title: '退勤打刻',
          body: '${_currentDateTime.hour}時${_currentDateTime.minute}分に退勤打刻しました',
        );

        // 最新の打刻情報を再取得
        await _fetchLatestTimeClocks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('退勤打刻に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Clock out error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isClockActionLoading = false;
      });
    }
  }

  Widget _buildLoginNeededContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.login, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'freeeへのログインが必要です',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('アプリを使用するにはfreeeへログインしてください', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _showLoginScreen,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('ログイン'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationNeededContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.warning, size: 64, color: Colors.amber),
          const SizedBox(height: 16),
          const Text(
            'OAuth認証の設定が必要です',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'freeeアプリケーションのClient IDとClient Secretを設定してください',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _showSettingsScreen,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('設定画面を開く'),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final nameParts = name.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }

    return name.substring(0, 1).toUpperCase();
  }
}
