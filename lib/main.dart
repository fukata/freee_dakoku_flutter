import 'package:flutter/material.dart';
import 'services/settings_service.dart';
import 'screens/oauth_settings_screen.dart';
import 'screens/login_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _checkSettings();
  }

  Future<void> _checkSettings() async {
    final isConfigured = await SettingsService.isOAuthConfigured();
    final isLoggedIn =
        isConfigured ? await SettingsService.isLoggedIn() : false;

    setState(() {
      _isConfigured = isConfigured;
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });

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
          const Text('ログイン成功！メイン画面です'),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _logout, child: const Text('ログアウト')),
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
}
