import '../services/settings_service.dart';

class ReminderUtils {
  /// 打刻リマインダーをスキップするかどうかを判断
  ///
  /// [lastTimeClock] 最後の打刻情報
  /// [currentDateTime] 現在の日時
  ///
  /// 戻り値: リマインダーをスキップすべき場合は true
  static bool isSkipReminder(
    TimeClock? lastTimeClock,
    DateTime currentDateTime,
  ) {
    if (lastTimeClock == null) {
      return false;
    }

    // 今日の日付を取得
    final today = DateTime(
      currentDateTime.year,
      currentDateTime.month,
      currentDateTime.day,
    );

    // 最後の打刻がある場合
    final lastTimeClockDate = DateTime(
      lastTimeClock.dateTime!.year,
      lastTimeClock.dateTime!.month,
      lastTimeClock.dateTime!.day,
    );

    return lastTimeClockDate == today;
  }
}
