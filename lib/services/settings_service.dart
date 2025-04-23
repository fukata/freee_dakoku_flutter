import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String clientIdKey = 'oauth_client_id';
  static const String clientSecretKey = 'oauth_client_secret';

  // ClientIDを保存
  static Future<bool> saveClientId(String clientId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(clientIdKey, clientId);
  }

  // Client Secretを保存
  static Future<bool> saveClientSecret(String clientSecret) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(clientSecretKey, clientSecret);
  }

  // ClientIDを取得
  static Future<String?> getClientId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(clientIdKey);
  }

  // Client Secretを取得
  static Future<String?> getClientSecret() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(clientSecretKey);
  }

  // OAuth設定が完了しているかチェック
  static Future<bool> isOAuthConfigured() async {
    final clientId = await getClientId();
    final clientSecret = await getClientSecret();
    return clientId != null &&
        clientId.isNotEmpty &&
        clientSecret != null &&
        clientSecret.isNotEmpty;
  }

  // 設定をクリア
  static Future<bool> clearSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(clientIdKey);
    return prefs.remove(clientSecretKey);
  }
}
