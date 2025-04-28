import '../services/settings_service.dart';

class ReminderUtils {
  /// 打刻リマインダーをスキップするかどうかを判断
  ///
  /// [lastTimeClockDateTime] 最後の打刻情報
  /// [currentDateTime] 現在の日時
  ///
  /// 戻り値: リマインダーをスキップすべき場合は true
  static bool isSkipReminder(
    DateTime lastTimeClockDateTime,
    DateTime currentDateTime,
  ) {
    // 今日の日付を取得
    final today = DateTime(
      currentDateTime.year,
      currentDateTime.month,
      currentDateTime.day,
    );

    // 最後の打刻がある場合
    final lastTimeClockDate = DateTime(
      lastTimeClockDateTime.year,
      lastTimeClockDateTime.month,
      lastTimeClockDateTime.day,
    );

    return lastTimeClockDate == today;
  }

  /// 出勤リマインダーを通知するかどうかを判断
  static bool isNeedNotifyForClockIn({
    required DateTime now,
    required DateTime startDateTime,
    required bool hasCheckedIn,
  }) {
    return now.isAfter(startDateTime) && !hasCheckedIn;
  }

  /// 退勤リマインダーを通知するかどうかを判断
  static bool isNeedNotifyForClockOut({
    required DateTime now,
    required DateTime endDateTime,
    required bool hasCheckedIn,
    required bool hasCheckedOut,
  }) {
    return now.isAfter(endDateTime) && hasCheckedIn && !hasCheckedOut;
  }
}
