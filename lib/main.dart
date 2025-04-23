import 'package:flutter/material.dart';
import 'services/settings_service.dart';
import 'screens/oauth_settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _checkSettings();
  }

  Future<void> _checkSettings() async {
    final isConfigured = await SettingsService.isOAuthConfigured();

    setState(() {
      _isConfigured = isConfigured;
      _isLoading = false;
    });

    if (!isConfigured) {
      _showSettingsScreen();
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

  void _openSettings() {
    _showSettingsScreen();
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
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isConfigured
              ? _buildHomeContent()
              : _buildConfigurationNeededContent(),
    );
  }

  Widget _buildHomeContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('OAuth認証設定が完了しています'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _openSettings,
            child: const Text('OAuth設定を変更する'),
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
