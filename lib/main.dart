import 'package:flutter/material.dart';
import 'services/settings_service.dart';
import 'screens/oauth_settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/user_profile_screen.dart';

void main() {
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

  @override
  void initState() {
    super.initState();
    _checkSettings();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'OAuth設定',
          ),
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'ログアウト',
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (_userInfo != null) ...[
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                _getInitials(_userInfo!.displayName),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'こんにちは、${_userInfo!.displayName}さん',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_userInfo!.email),
          ] else ...[
            const Text('ログイン成功！'),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _viewUserProfile,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('詳細プロフィールを表示'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[100],
              foregroundColor: Colors.red[900],
            ),
            child: const Text('ログアウト'),
          ),
        ],
      ),
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
