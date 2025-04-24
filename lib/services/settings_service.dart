import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:oauth2_client/oauth2_client.dart';
import 'package:oauth2_client/oauth2_helper.dart';
import 'package:oauth2_client/access_token_response.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FreeeOAuth2Client extends OAuth2Client {
  FreeeOAuth2Client()
    : super(
        authorizeUrl:
            'https://accounts.secure.freee.co.jp/public_api/authorize',
        tokenUrl: 'https://accounts.secure.freee.co.jp/public_api/token',
        redirectUri: 'freeedakoku://callback',
        customUriScheme: 'freeedakoku',
      );
}

class UserInfo {
  final int id;
  final String email;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final HrUserInfo? hr; // HR関連のユーザー情報

  UserInfo({
    required this.id,
    required this.email,
    required this.displayName,
    this.firstName,
    this.lastName,
    this.hr,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'],
      email: json['email'],
      displayName: json['display_name'],
      firstName: json['first_name'],
      lastName: json['last_name'],
    );
  }

  // HR情報を追加するためのコピーメソッド
  UserInfo copyWithHr(HrUserInfo hrUserInfo) {
    return UserInfo(
      id: this.id,
      email: this.email,
      displayName: this.displayName,
      firstName: this.firstName,
      lastName: this.lastName,
      hr: hrUserInfo,
    );
  }
}

class HrCompanyInfo {
  final int id;
  final String name;
  final String role;
  final String externalCid;
  final int employeeId;
  final String displayName;

  HrCompanyInfo({
    required this.id,
    required this.name,
    required this.role,
    required this.externalCid,
    required this.employeeId,
    required this.displayName,
  });

  factory HrCompanyInfo.fromJson(Map<String, dynamic> json) {
    return HrCompanyInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      externalCid: json['external_cid'] ?? '',
      employeeId: json['employee_id'] ?? 0,
      displayName: json['display_name'] ?? '',
    );
  }

  // Implement equality based on the id field
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HrCompanyInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class HrUserInfo {
  final int id;
  final List<HrCompanyInfo> companies;

  HrUserInfo({required this.id, required this.companies});

  factory HrUserInfo.fromJson(Map<String, dynamic> json) {
    final List<dynamic> companiesJson = json['companies'] ?? [];
    final List<HrCompanyInfo> companies =
        companiesJson
            .map<HrCompanyInfo>((company) => HrCompanyInfo.fromJson(company))
            .toList();

    return HrUserInfo(id: json['id'] ?? 0, companies: companies);
  }
}

class TimeClock {
  final int id;
  final String? type;
  final DateTime baseDate;
  final DateTime? dateTime;

  TimeClock({
    required this.id,
    required this.type,
    required this.baseDate,
    this.dateTime,
  });

  factory TimeClock.fromJson(Map<String, dynamic> json) {
    return TimeClock(
      id: json['id'],
      type: json['type'],
      baseDate: DateTime.parse(json['date']),
      dateTime:
          json['datetime'] != null ? DateTime.parse(json['datetime']) : null,
    );
  }
}

class SettingsService {
  static const String clientIdKey = 'oauth_client_id';
  static const String clientSecretKey = 'oauth_client_secret';
  static const String accessTokenKey = 'oauth_access_token';
  static const String refreshTokenKey = 'oauth_refresh_token';
  static const String tokenExpiryKey = 'oauth_token_expiry';

  // App settings keys
  static const String autoStartKey = 'app_auto_start';
  static const String startWorkTimeKey = 'start_work_time';
  static const String endWorkTimeKey = 'end_work_time';
  static const String enableNotificationsKey = 'enable_notifications';
  static const String notificationIntervalKey = 'notification_interval';

  // Keys for company settings
  static const String selectedCompanyIdKey = 'selected_company_id';

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

  // アクセストークンを保存
  static Future<bool> saveAccessToken(String token, int expiresIn) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
    await prefs.setString(accessTokenKey, token);
    return prefs.setInt(tokenExpiryKey, expiry);
  }

  // リフレッシュトークンを保存
  static Future<bool> saveRefreshToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(refreshTokenKey, token);
  }

  // アクセストークンを取得
  static Future<String?> getAccessToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(accessTokenKey);
  }

  // リフレッシュトークンを取得
  static Future<String?> getRefreshToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(refreshTokenKey);
  }

  // トークンの有効期限を取得
  static Future<int?> getTokenExpiry() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(tokenExpiryKey);
  }

  // ログイン状態をチェック
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    final expiry = await getTokenExpiry();

    if (token == null || expiry == null) {
      return false;
    }

    // トークンが有効期限切れでないかチェック
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= expiry) {
      // トークンが期限切れの場合はリフレッシュを試みる
      try {
        final refreshed = await refreshAccessToken();
        return refreshed;
      } catch (e) {
        debugPrint('Token refresh failed: $e');
        return false;
      }
    }

    return true;
  }

  // OAuth2 Helper を取得
  static Future<OAuth2Helper> _getOAuth2Helper() async {
    final clientId = await getClientId();
    final clientSecret = await getClientSecret();

    if (clientId == null || clientSecret == null) {
      throw Exception('OAuth credentials not configured');
    }

    final oauth2Client = FreeeOAuth2Client();
    return OAuth2Helper(
      oauth2Client,
      clientId: clientId,
      clientSecret: clientSecret,
      scopes: ['read'],
      // カスタムパラメータを設定 (removed as it is not supported)
    );
  }

  // ログインを実行
  static Future<bool> performLogin() async {
    try {
      if (!await isOAuthConfigured()) return false;

      final oauth2Helper = await _getOAuth2Helper();
      final accessToken = await oauth2Helper.getToken();

      if (accessToken != null) {
        await saveAccessToken(
          accessToken.accessToken!,
          accessToken.expiresIn ?? 3600,
        );

        if (accessToken.refreshToken != null) {
          await saveRefreshToken(accessToken.refreshToken!);
        }

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  // 認証コードをトークンに交換
  static Future<bool> exchangeCodeForToken(
    String code,
    String redirectUrl,
  ) async {
    try {
      final clientId = await getClientId();
      final clientSecret = await getClientSecret();
      if (clientId == null || clientSecret == null) return false;

      final response = await http.post(
        Uri.parse('https://accounts.secure.freee.co.jp/public_api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUrl,
          'client_id': clientId,
          'client_secret': clientSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveAccessToken(data['access_token'], data['expires_in']);
        await saveRefreshToken(data['refresh_token']);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Token exchange error: $e');
      return false;
    }
  }

  // アクセストークンをリフレッシュ
  static Future<bool> refreshAccessToken() async {
    try {
      final oauth2Helper = await _getOAuth2Helper();
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        throw Exception('Refresh token not available');
      }

      // 現在のトークン情報を持つAccessTokenResponseを作成
      final currentToken = AccessTokenResponse.fromMap({
        'refresh_token': refreshToken,
      });

      final accessToken = await oauth2Helper.refreshToken(currentToken);

      await saveAccessToken(
        accessToken.accessToken!,
        accessToken.expiresIn ?? 3600,
      );

      if (accessToken.refreshToken != null) {
        await saveRefreshToken(accessToken.refreshToken!);
      }

      return true;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }

  // ログアウト
  static Future<bool> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);
    return prefs.remove(tokenExpiryKey);
  }

  // 設定をクリア
  static Future<bool> clearSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(clientIdKey);
    await prefs.remove(clientSecretKey);
    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);
    return prefs.remove(tokenExpiryKey);
  }

  // ユーザー情報を取得
  static Future<UserInfo?> getUserInfo() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) return null;

      final response = await http.get(
        Uri.parse('https://api.freee.co.jp/api/1/users/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserInfo.fromJson(data['user']);
      } else if (response.statusCode == 401) {
        // アクセストークンの期限切れの場合、リフレッシュを試みる
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          // リフレッシュに成功したら再度APIを呼び出す
          return getUserInfo();
        }
      }
      debugPrint('Failed to get user info: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error getting user info: $e');
      return null;
    }
  }

  // 最新の打刻情報を取得
  static Future<List<TimeClock>?> getLatestTimeClocks({
    HrCompanyInfo? selectedCompany,
  }) async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) return null;

      // 選択された事業所がない場合はユーザー情報を取得
      int employeeId;
      if (selectedCompany != null) {
        employeeId = selectedCompany.employeeId;
      } else {
        // 現在のユーザー情報を取得し、HR情報がなければ失敗
        final userInfo = await getFullUserInfo();
        if (userInfo == null ||
            userInfo.hr == null ||
            userInfo.hr!.companies.isEmpty)
          return null;

        // 最初の事業所のemployee_idを使う（後方互換性のため）
        employeeId = userInfo.hr!.companies.first.employeeId;
      }

      // 1ヶ月前の日付を取得
      final now = DateTime.now();
      final fromDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 30));
      final formattedFromDate =
          '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
      final companyId = selectedCompany?.id ?? 0;

      final response = await http.get(
        Uri.parse(
          'https://api.freee.co.jp/hr/api/v1/employees/$employeeId/time_clocks?from_date=$formattedFromDate&company_id=$companyId',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> timeClockList = data;
        return timeClockList
            .map<TimeClock>((tc) => TimeClock.fromJson(tc))
            .toList();
      } else if (response.statusCode == 401) {
        // アクセストークンの期限切れの場合、リフレッシュを試みる
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          // リフレッシュに成功したら再度APIを呼び出す
          return getLatestTimeClocks(selectedCompany: selectedCompany);
        }
      }
      debugPrint('Failed to get time clocks: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error getting time clocks: $e');
      return null;
    }
  }

  // 出勤打刻を実行
  static Future<bool> clockIn({
    required HrCompanyInfo selectedCompany,
    required String baseDate,
    required String datetime,
  }) async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) return false;

      // 選択された事業所がない場合はユーザー情報を取得
      final employeeId = selectedCompany.employeeId;

      final requestBody = {'type': 'clock_in'};
      requestBody['company_id'] = selectedCompany.id.toString();
      // requestBody['base_date'] = baseDate;
      // requestBody['datetime'] = datetime;

      final response = await http.post(
        Uri.parse(
          'https://api.freee.co.jp/hr/api/v1/employees/$employeeId/time_clocks',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error clocking in: $e');
      return false;
    }
  }

  // 退勤打刻を実行
  static Future<bool> clockOut({
    required HrCompanyInfo selectedCompany,
    required String baseDate,
    required String datetime,
  }) async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) return false;

      // 選択された事業所がない場合はユーザー情報を取得
      final employeeId = selectedCompany.employeeId;

      final requestBody = {'type': 'clock_out'};
      requestBody['company_id'] = selectedCompany.id.toString();
      // requestBody['base_date'] = baseDate;
      // requestBody['datetime'] = datetime;

      final response = await http.post(
        Uri.parse(
          'https://api.freee.co.jp/hr/api/v1/employees/$employeeId/time_clocks',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error clocking out: $e');
      return false;
    }
  }

  // App Settings Methods

  // Auto Start
  static Future<bool> saveAutoStart(bool autoStart) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(autoStartKey, autoStart);
  }

  static Future<bool> getAutoStart() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(autoStartKey) ?? false;
  }

  // Work Hours
  static Future<bool> saveStartWorkTime(String startTime) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(startWorkTimeKey, startTime);
  }

  static Future<String> getStartWorkTime() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(startWorkTimeKey) ?? '09:00';
  }

  static Future<bool> saveEndWorkTime(String endTime) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(endWorkTimeKey, endTime);
  }

  static Future<String> getEndWorkTime() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(endWorkTimeKey) ?? '18:00';
  }

  // Notification Settings
  static Future<bool> saveEnableNotifications(bool enable) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(enableNotificationsKey, enable);
  }

  static Future<bool> getEnableNotifications() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(enableNotificationsKey) ?? true;
  }

  // Notification Interval Settings (in minutes)
  static Future<bool> saveNotificationInterval(int minutes) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setInt(notificationIntervalKey, minutes);
  }

  static Future<int> getNotificationInterval() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(notificationIntervalKey) ?? 15; // Default is 15 minutes
  }

  // Company Selection
  static Future<bool> saveSelectedCompanyId(int companyId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setInt(selectedCompanyIdKey, companyId);
  }

  static Future<int?> getSelectedCompanyId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(selectedCompanyIdKey);
  }

  // 人事労務APIからユーザー情報を取得
  static Future<HrUserInfo?> getHrUserInfo() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) return null;

      final response = await http.get(
        Uri.parse('https://api.freee.co.jp/hr/api/v1/users/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // APIレスポンスは直接HrUserInfoに変換できる形式
        return HrUserInfo.fromJson(data);
      } else if (response.statusCode == 401) {
        // アクセストークンの期限切れの場合、リフレッシュを試みる
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          // リフレッシュに成功したら再度APIを呼び出す
          return getHrUserInfo();
        }
      }
      debugPrint(
        'Failed to get HR user info: ${response.statusCode} ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('Error getting HR user info: $e');
      return null;
    }
  }

  // 通常のユーザー情報とHRユーザー情報の両方を取得
  static Future<UserInfo?> getFullUserInfo() async {
    try {
      // まず通常のユーザー情報を取得
      final userInfo = await getUserInfo();
      if (userInfo == null) return null;

      // 次にHRユーザー情報を取得
      final hrUserInfo = await getHrUserInfo();

      // HR情報をセットして返す（HR情報がない場合はそのまま返す）
      if (hrUserInfo != null) {
        return userInfo.copyWithHr(hrUserInfo);
      }

      return userInfo;
    } catch (e) {
      debugPrint('Error getting full user info: $e');
      return null;
    }
  }
}
