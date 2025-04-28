import 'package:flutter_test/flutter_test.dart';
import 'package:freee_dakoku_flutter/services/settings_service.dart';
import 'package:freee_dakoku_flutter/utils/reminder_utils.dart';

void main() {
  group('ReminderUtils - isSkipReminder', () {
    final DateTime now = DateTime(2025, 4, 25, 10, 0); // 2025-04-25 10:00

    test('最後の打刻が今日の場合は true を返す', () {
      final TimeClock todayClock = TimeClock(
        id: 1,
        type: 'clock_in',
        baseDate: DateTime(2025, 4, 25),
        dateTime: DateTime(2025, 4, 25, 9, 0), // 今日の9:00に打刻
      );

      expect(ReminderUtils.isSkipReminder(todayClock.dateTime!.toLocal(), now), true);
    });

    test('最後の打刻が昨日の場合は false を返す', () {
      final TimeClock yesterdayClock = TimeClock(
        id: 2,
        type: 'clock_out',
        baseDate: DateTime(2025, 4, 24),
        dateTime: DateTime(2025, 4, 24, 18, 0), // 昨日の18:00に打刻
      );

      expect(ReminderUtils.isSkipReminder(yesterdayClock.dateTime!.toLocal(), now), false);
    });

    test('最後の打刻が一週間前の場合は false を返す', () {
      final TimeClock lastWeekClock = TimeClock(
        id: 3,
        type: 'clock_in',
        baseDate: DateTime(2025, 4, 18),
        dateTime: DateTime(2025, 4, 18, 9, 0), // 一週間前の9:00に打刻
      );

      expect(ReminderUtils.isSkipReminder(lastWeekClock.dateTime!.toLocal(), now), false);
    });

    test('最後の打刻が未来の日付の場合は false を返す (異常ケース)', () {
      final TimeClock futureClock = TimeClock(
        id: 4,
        type: 'clock_in',
        baseDate: DateTime(2025, 4, 26),
        dateTime: DateTime(2025, 4, 26, 9, 0), // 明日の9:00に打刻 (通常はあり得ない)
      );

      expect(ReminderUtils.isSkipReminder(futureClock.dateTime!.toLocal(), now), false);
    });

    test('時間帯の異なる今日の打刻でも true を返す', () {
      // 今日の深夜0:01に打刻した場合
      final TimeClock earlyMorningClock = TimeClock(
        id: 5,
        type: 'clock_in',
        baseDate: DateTime(2025, 4, 25),
        dateTime: DateTime(2025, 4, 25, 0, 1), // 今日の0:01に打刻
      );

      // 今日の23:59に打刻した場合
      final TimeClock lateNightClock = TimeClock(
        id: 6,
        type: 'clock_out',
        baseDate: DateTime(2025, 4, 25),
        dateTime: DateTime(2025, 4, 25, 23, 59), // 今日の23:59に打刻
      );

      expect(ReminderUtils.isSkipReminder(earlyMorningClock.dateTime!.toLocal(), now), true);
      expect(ReminderUtils.isSkipReminder(lateNightClock.dateTime!.toLocal(), now), true);
    });

    test('isNeedNotifyForClockIn', () {
      final now = DateTime(2024, 9, 16, 9, 1);
      final startDateTime = DateTime(2024, 9, 16, 9, 0);
      expect(ReminderUtils.isNeedNotifyForClockIn(now: now, startDateTime: startDateTime, hasCheckedIn: false), true);
      expect(ReminderUtils.isNeedNotifyForClockIn(now: now, startDateTime: startDateTime, hasCheckedIn: true), false);
    });

    test('isNeedNotifyForClockOut', () {
      final now = DateTime(2024, 9, 16, 18, 1);
      final endDateTime = DateTime(2024, 9, 16, 18, 0);
      expect(ReminderUtils.isNeedNotifyForClockOut(now: now, endDateTime: endDateTime, hasCheckedIn: true, hasCheckedOut: false), true);
      expect(ReminderUtils.isNeedNotifyForClockOut(now: now, endDateTime: endDateTime, hasCheckedIn: true, hasCheckedOut: true), false);
      expect(ReminderUtils.isNeedNotifyForClockOut(now: now, endDateTime: endDateTime, hasCheckedIn: false, hasCheckedOut: false), false);
    });
  });
}
