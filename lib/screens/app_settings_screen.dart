import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _isAutoStart = false;
  bool _enableNotifications = true;
  String _startWorkTime = '09:00';
  String _endWorkTime = '18:00';
  int _notificationInterval = 15; // Default to 15 minutes
  bool _isLoading = true;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
    await _notificationService.requestPermissions();
  }

  Future<void> _loadSettings() async {
    final autoStart = await SettingsService.getAutoStart();
    final startTime = await SettingsService.getStartWorkTime();
    final endTime = await SettingsService.getEndWorkTime();
    final enableNotifications = await SettingsService.getEnableNotifications();
    final notificationInterval =
        await SettingsService.getNotificationInterval();

    setState(() {
      _isAutoStart = autoStart;
      _startWorkTime = startTime;
      _endWorkTime = endTime;
      _enableNotifications = enableNotifications;
      _notificationInterval = notificationInterval;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    await SettingsService.saveAutoStart(_isAutoStart);
    await SettingsService.saveStartWorkTime(_startWorkTime);
    await SettingsService.saveEndWorkTime(_endWorkTime);
    await SettingsService.saveEnableNotifications(_enableNotifications);
    await SettingsService.saveNotificationInterval(_notificationInterval);

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('設定が保存されました')));

    Navigator.of(context).pop(true); // 設定が保存されたことを通知
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    // 現在の時刻を解析
    final currentTime = isStartTime ? _startWorkTime : _endWorkTime;
    final timeParts = currentTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final initialTime = TimeOfDay(hour: hour, minute: minute);

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      setState(() {
        final formattedHour = selectedTime.hour.toString().padLeft(2, '0');
        final formattedMinute = selectedTime.minute.toString().padLeft(2, '0');
        if (isStartTime) {
          _startWorkTime = '$formattedHour:$formattedMinute';
        } else {
          _endWorkTime = '$formattedHour:$formattedMinute';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アプリケーション設定'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '起動設定',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: const Text('パソコン起動時に自動起動する'),
                              subtitle: const Text('パソコンが起動したとき、自動的にアプリを起動します'),
                              value: _isAutoStart,
                              onChanged: (value) {
                                setState(() {
                                  _isAutoStart = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '勤務時間設定',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              title: const Text('始業時間'),
                              trailing: Text(
                                _startWorkTime,
                                style: const TextStyle(fontSize: 16),
                              ),
                              onTap: () => _selectTime(context, true),
                            ),
                            const Divider(),
                            ListTile(
                              title: const Text('終業時間'),
                              trailing: Text(
                                _endWorkTime,
                                style: const TextStyle(fontSize: 16),
                              ),
                              onTap: () => _selectTime(context, false),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '通知設定',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: const Text('勤怠時間の通知'),
                              subtitle: const Text('始業・終業時間になったら通知を表示します'),
                              value: _enableNotifications,
                              onChanged: (value) {
                                setState(() {
                                  _enableNotifications = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '通知間隔 (分)',
                                  style: TextStyle(fontSize: 16),
                                ),
                                DropdownButton<int>(
                                  value: _notificationInterval,
                                  items:
                                      [5, 10, 15, 30, 60]
                                          .map(
                                            (interval) => DropdownMenuItem<int>(
                                              value: interval,
                                              child: Text('$interval 分'),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _notificationInterval = value!;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await _notificationService
                                      .showTestNotification();
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                  ),
                                ),
                                child: const Text(
                                  'テスト通知を送信',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                        ),
                        child: const Text('保存', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
