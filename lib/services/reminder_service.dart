import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/database/nays_cbt_database.dart';

final class ReminderRecord {
  const ReminderRecord({
    required this.id,
    required this.title,
    required this.time,
    required this.repeat,
    required this.ringtone,
    this.enabled = true,
    this.nextOccurrence,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final TimeOfDay time;
  final ReminderRepeat repeat;
  final String ringtone;
  final bool enabled;
  final DateTime? nextOccurrence;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReminderRecord copyWith({
    String? id,
    String? title,
    TimeOfDay? time,
    ReminderRepeat? repeat,
    String? ringtone,
    bool? enabled,
    DateTime? nextOccurrence,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ReminderRecord(
    id: id ?? this.id,
    title: title ?? this.title,
    time: time ?? this.time,
    repeat: repeat ?? this.repeat,
    ringtone: ringtone ?? this.ringtone,
    enabled: enabled ?? this.enabled,
    nextOccurrence: nextOccurrence ?? this.nextOccurrence,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory ReminderRecord.fromMap(Map<String, Object?> map) => ReminderRecord(
    id: map['id'] as String,
    title: map['title'] as String,
    time: TimeOfDay(
      hour: int.parse((map['time_text'] as String).split(':')[0]),
      minute: int.parse((map['time_text'] as String).split(':')[1]),
    ),
    repeat: ReminderRepeat.fromValue(map['repeat_type'] as String),
    ringtone: _normalizeRingtone(map['ringtone'] as String? ?? 'default'),
    enabled: (map['enabled'] as int? ?? 1) == 1,
    nextOccurrence: map['next_occurrence'] == null
        ? null
        : DateTime.tryParse(map['next_occurrence'] as String),
    createdAt: map['created_at'] == null
        ? null
        : DateTime.tryParse(map['created_at'] as String),
    updatedAt: map['updated_at'] == null
        ? null
        : DateTime.tryParse(map['updated_at'] as String),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'time_text': _formatTime(time),
    'repeat_type': repeat.value,
    'ringtone': _normalizeRingtone(ringtone),
    'enabled': enabled ? 1 : 0,
    'next_occurrence': nextOccurrence?.toUtc().toIso8601String(),
    'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
    'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
  };

  static String _normalizeRingtone(String ringtone) {
    switch (ringtone) {
      case 'default_alarm':
      case 'defualt':
      case 'default':
        return 'default';
      case 'ringtone_1':
        return 'ringtone_1';
      default:
        return 'default';
    }
  }

  static String _formatTime(TimeOfDay timeOfDay) =>
      '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}';
}

enum ReminderRepeat {
  once('once'),
  daily('daily'),
  workingDays('working_days'),
  weekends('weekends');

  const ReminderRepeat(this.value);

  final String value;

  static ReminderRepeat fromValue(String value) {
    switch (value) {
      case 'daily':
        return ReminderRepeat.daily;
      case 'working_days':
        return ReminderRepeat.workingDays;
      case 'weekends':
        return ReminderRepeat.weekends;
      case 'once':
      default:
        return ReminderRepeat.once;
    }
  }

  String get label {
    switch (this) {
      case once:
        return 'Once';
      case daily:
        return 'Daily';
      case workingDays:
        return 'Working Days';
      case weekends:
        return 'Weekends';
    }
  }
}

class ReminderScheduler {
  ReminderScheduler();

  static const _alarmWindowChannel = MethodChannel(
    'com.nays.nays_mobile/alarm_window',
  );

  static String androidSoundResourceNameFor(String ringtone) {
    switch (ringtone) {
      case 'ringtone_1':
        return 'nays_ringtone_1';
      case 'default':
      case 'default_alarm':
      case 'defualt':
      default:
        return 'nays_default';
    }
  }

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool? _fullScreenIntentPermissionGranted;

  bool? get fullScreenIntentPermissionGranted =>
      _fullScreenIntentPermissionGranted;

  static AndroidNotificationChannel _alarmChannelFor(String ringtone) {
    final soundName = androidSoundResourceNameFor(ringtone);
    final toneName = ringtone == 'ringtone_1'
        ? 'Alarm Tone 1'
        : 'Default Alarm';
    return AndroidNotificationChannel(
      'nays_reminder_v2_$soundName',
      'NAYS Reminder Alerts - $toneName',
      description: 'Alarm notifications for study reminders.',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundName),
      enableVibration: true,
    );
  }

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_alarmChannelFor('default'));
    await androidPlugin?.createNotificationChannel(
      _alarmChannelFor('ringtone_1'),
    );
    final notificationsGranted = await androidPlugin
        ?.requestNotificationsPermission();
    if (notificationsGranted == false) {
      throw PlatformException(
        code: 'notifications_permission_denied',
        message: 'Notification permission was denied.',
      );
    }
    final exactAlarmsGranted = await androidPlugin
        ?.requestExactAlarmsPermission();
    if (exactAlarmsGranted == false) {
      throw PlatformException(
        code: 'exact_alarm_permission_denied',
        message: 'Exact-alarm permission was denied.',
      );
    }
    if (androidPlugin != null) {
      _fullScreenIntentPermissionGranted = await _alarmWindowChannel
          .invokeMethod<bool>('canUseFullScreenIntent');
    }
    _initialized = true;
  }

  Future<bool?> requestFullScreenIntentPermission() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    _fullScreenIntentPermissionGranted = await androidPlugin
        ?.requestFullScreenIntentPermission();
    return _fullScreenIntentPermissionGranted;
  }

  Future<void> scheduleReminder(ReminderRecord reminder) async {
    if (!reminder.enabled) {
      await cancelReminder(reminder.id);
      return;
    }

    final now = DateTime.now();
    final occurrences = _scheduleOccurrences(reminder, now);
    if (occurrences.isEmpty) {
      throw StateError('No future occurrence could be calculated.');
    }

    await initialize();
    await cancelReminder(reminder.id);

    final nextOccurrence = occurrences
        .map((occurrence) => occurrence.date)
        .reduce((first, second) => first.isBefore(second) ? first : second);
    final updatedReminder = reminder.copyWith(nextOccurrence: nextOccurrence);
    await NaysCbtDatabase.instance.upsertReminder(updatedReminder.toMap());

    for (final occurrence in occurrences) {
      await _scheduleNotification(
        reminder: updatedReminder,
        scheduledDate: occurrence.date,
        notificationId: _notificationId(reminder.id, occurrence.slot),
        matchDateTimeComponents: occurrence.matchDateTimeComponents,
      );
    }
  }

  Future<void> scheduleSnooze(
    ReminderRecord reminder,
    DateTime scheduledDate,
  ) async {
    if (!scheduledDate.isAfter(DateTime.now())) {
      throw ArgumentError.value(
        scheduledDate,
        'scheduledDate',
        'A snooze must be scheduled in the future.',
      );
    }
    await initialize();
    await _scheduleNotification(
      reminder: reminder,
      scheduledDate: scheduledDate,
      notificationId: _notificationId(reminder.id, 8),
    );
  }

  Future<void> _scheduleNotification({
    required ReminderRecord reminder,
    required DateTime scheduledDate,
    required int notificationId,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final scheduled = tz.TZDateTime.from(scheduledDate, tz.local);
    final channel = _alarmChannelFor(reminder.ringtone);
    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        androidSoundResourceNameFor(reminder.ringtone),
      ),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      actions: [
        const AndroidNotificationAction(
          'dismiss_action',
          'Dismiss',
          showsUserInterface: false,
        ),
      ],
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    final details = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      notificationId,
      'Reminder',
      reminder.title,
      scheduled,
      details,
      payload: reminder.id,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  Future<void> cancelReminder(String reminderId) async {
    final pending = await _notifications.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload == reminderId) {
        await _notifications.cancel(request.id);
      }
    }
    for (var slot = 0; slot <= 8; slot++) {
      await _notifications.cancel(_notificationId(reminderId, slot));
    }
    await _notifications.cancel(reminderId.hashCode);
  }

  Future<void> rescheduleAllEnabled() async {
    final reminders = await NaysCbtDatabase.instance.getReminderList();
    for (final row in reminders) {
      final reminder = ReminderRecord.fromMap(row);
      if (reminder.enabled) {
        await scheduleReminder(reminder);
      } else {
        await cancelReminder(reminder.id);
      }
    }
  }

  static DateTime? computeNextOccurrence(
    ReminderRecord reminder,
    DateTime now,
  ) {
    final occurrences = _scheduleOccurrences(reminder, now);
    if (occurrences.isEmpty) return null;
    return occurrences
        .map((occurrence) => occurrence.date)
        .reduce((first, second) => first.isBefore(second) ? first : second);
  }

  static List<_ReminderOccurrence> _scheduleOccurrences(
    ReminderRecord reminder,
    DateTime now,
  ) {
    switch (reminder.repeat) {
      case ReminderRepeat.once:
        return [_ReminderOccurrence(_nextAtTime(reminder.time, now), 0, null)];
      case ReminderRepeat.daily:
        return [
          _ReminderOccurrence(
            _nextAtTime(reminder.time, now),
            0,
            DateTimeComponents.time,
          ),
        ];
      case ReminderRepeat.workingDays:
        return [
          for (
            var weekday = DateTime.monday;
            weekday <= DateTime.friday;
            weekday++
          )
            _ReminderOccurrence(
              _nextAtWeekday(reminder.time, weekday, now),
              weekday,
              DateTimeComponents.dayOfWeekAndTime,
            ),
        ];
      case ReminderRepeat.weekends:
        return [
          for (final weekday in [DateTime.saturday, DateTime.sunday])
            _ReminderOccurrence(
              _nextAtWeekday(reminder.time, weekday, now),
              weekday,
              DateTimeComponents.dayOfWeekAndTime,
            ),
        ];
    }
  }

  static DateTime _nextAtTime(TimeOfDay time, DateTime now) {
    final candidate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return candidate.isAfter(now)
        ? candidate
        : candidate.add(const Duration(days: 1));
  }

  static DateTime _nextAtWeekday(TimeOfDay time, int weekday, DateTime now) {
    final daysUntil = (weekday - now.weekday + 7) % 7;
    var candidate = DateTime(
      now.year,
      now.month,
      now.day + daysUntil,
      time.hour,
      time.minute,
    );
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  static int _notificationId(String reminderId, int slot) {
    var hash = 0x811c9dc5;
    for (final codeUnit in reminderId.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    return (hash & 0x07ffffff) * 9 + slot;
  }

  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    final reminderId = response.payload;
    if (reminderId == null || reminderId.isEmpty) return;
    final reminderMap = await NaysCbtDatabase.instance.getReminder(reminderId);
    if (reminderMap == null) return;
    final reminder = ReminderRecord.fromMap(reminderMap);
    if (!reminder.enabled) return;
    if (response.actionId == 'dismiss_action') {
      await NaysCbtDatabase.instance.updateReminderEnabled(reminderId, false);
      await ReminderScheduler().cancelReminder(reminderId);
      return;
    }

    if (reminder.repeat == ReminderRepeat.once) {
      await NaysCbtDatabase.instance.updateReminderEnabled(reminderId, false);
      await ReminderScheduler().cancelReminder(reminderId);
    }
  }
}

final class _ReminderOccurrence {
  const _ReminderOccurrence(this.date, this.slot, this.matchDateTimeComponents);

  final DateTime date;
  final int slot;
  final DateTimeComponents? matchDateTimeComponents;
}
