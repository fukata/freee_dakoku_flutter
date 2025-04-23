import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class OAuthSettingsScreen extends StatefulWidget {
  const OAuthSettingsScreen({super.key});

  @override
  State<OAuthSettingsScreen> createState() => _OAuthSettingsScreenState();
}

class _OAuthSettingsScreenState extends State<OAuthSettingsScreen> {
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _clientSecretController = TextEditingController();
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final clientId = await SettingsService.getClientId();
    final clientSecret = await SettingsService.getClientSecret();

    setState(() {
      if (clientId != null) _clientIdController.text = clientId;
      if (clientSecret != null) _clientSecretController.text = clientSecret;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await SettingsService.saveClientId(_clientIdController.text);
    await SettingsService.saveClientSecret(_clientSecretController.text);

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('設定が保存されました')));

    Navigator.of(context).pop(true); // 設定が完了したことを通知するためにtrue返す
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OAuth設定'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'freeeアプリケーションの認証情報を入力してください。',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _clientIdController,
                        decoration: const InputDecoration(
                          labelText: 'Client ID',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Client IDを入力してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _clientSecretController,
                        decoration: const InputDecoration(
                          labelText: 'Client Secret',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Client Secretを入力してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                        ),
                        child: const Text('保存', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
