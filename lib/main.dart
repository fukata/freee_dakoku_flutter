import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'screens/oauth_settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/app_settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  final NotificationService _notificationService = NotificationService();
  DateTime _currentDateTime = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    // Set up a timer to update the time every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        _currentDateTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _notificationService.init();
    await _checkSettings();
  }

  Future<void> _checkSettings() async {
    final isConfigured = await SettingsService.isOAuthConfigured();
    final isLoggedIn =
        isConfigured ? await SettingsService.isLoggedIn() : false;

    if (isLoggedIn) {
      // ログイン済みの場合はユーザー情報を取得
      final userInfo = await SettingsService.getUserInfo();
      setState(() {
        _isConfigured = isConfigured;
        _isLoggedIn = isLoggedIn;
        _userInfo = userInfo;
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

  void _showAppSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AppSettingsScreen()));
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
                    value: 'oauth',
                    child: Row(
                      children: [
                        Icon(Icons.key),
                        SizedBox(width: 8),
                        Text('OAuth設定'),
                      ],
                    ),
                  ),
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
            child: Row(
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
                Column(
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
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
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
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(24),
          ),
          child: Icon(icon, size: 40),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return weekdays[weekday - 1];
  }

  void _clockIn() async {
    // TODO: Implement clock-in functionality with freee API
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('出勤打刻しました')));
    // Send a notification
    await _notificationService.showNotification(
      id: 1,
      title: '出勤打刻',
      body: '${_currentDateTime.hour}時${_currentDateTime.minute}分に出勤打刻しました',
    );
  }

  void _clockOut() async {
    // TODO: Implement clock-out functionality with freee API
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('退勤打刻しました')));
    // Send a notification
    await _notificationService.showNotification(
      id: 2,
      title: '退勤打刻',
      body: '${_currentDateTime.hour}時${_currentDateTime.minute}分に退勤打刻しました',
    );
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
