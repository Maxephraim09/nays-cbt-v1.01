import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nays_mobile/services/reminder_service.dart';

void main() {
  test('maps reminder ringtones to packaged Android raw resources', () {
    expect(
      ReminderScheduler.androidSoundResourceNameFor('default'),
      'nays_default',
    );
    expect(
      ReminderScheduler.androidSoundResourceNameFor('ringtone_1'),
      'nays_ringtone_1',
    );
    expect(
      ReminderScheduler.androidSoundResourceNameFor('defualt'),
      'nays_default',
    );
  });

  group('ReminderRecord', () {
    test('round-trips reminder settings through the database map', () {
      final reminder = ReminderRecord(
        id: 'reminder-1',
        title: 'Read Mathematics',
        time: const TimeOfDay(hour: 19, minute: 5),
        repeat: ReminderRepeat.workingDays,
        ringtone: 'ringtone_1',
        enabled: false,
        nextOccurrence: DateTime(2026, 11, 19, 19, 5),
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 2),
      );

      final restored = ReminderRecord.fromMap(reminder.toMap());

      expect(restored.id, reminder.id);
      expect(restored.title, reminder.title);
      expect(restored.time, reminder.time);
      expect(restored.repeat, reminder.repeat);
      expect(restored.ringtone, reminder.ringtone);
      expect(restored.enabled, isFalse);
      expect(
        restored.nextOccurrence!.isAtSameMomentAs(reminder.nextOccurrence!),
        isTrue,
      );
      expect(restored.createdAt!.isAtSameMomentAs(reminder.createdAt!), isTrue);
      expect(restored.updatedAt!.isAtSameMomentAs(reminder.updatedAt!), isTrue);
    });

    test('normalizes legacy ringtone values when loading reminders', () {
      final reminder = ReminderRecord.fromMap({
        'id': 'legacy',
        'title': 'Study',
        'time_text': '08:00',
        'repeat_type': 'unknown',
        'ringtone': 'defualt',
        'enabled': 1,
        'created_at': null,
        'updated_at': null,
        'next_occurrence': null,
      });

      expect(reminder.ringtone, 'default');
      expect(reminder.repeat, ReminderRepeat.once);
      expect(reminder.enabled, isTrue);
    });
  });

  group('ReminderScheduler.computeNextOccurrence', () {
    final time = const TimeOfDay(hour: 8, minute: 30);

    ReminderRecord reminder(ReminderRepeat repeat) => ReminderRecord(
      id: 'reminder',
      title: 'Study',
      time: time,
      repeat: repeat,
      ringtone: 'default',
    );

    test('moves a passed once reminder to tomorrow', () {
      final now = DateTime(2026, 11, 16, 9);

      expect(
        ReminderScheduler.computeNextOccurrence(
          reminder(ReminderRepeat.once),
          now,
        ),
        DateTime(2026, 11, 17, 8, 30),
      );
    });

    test('chooses the next working day and weekend occurrence', () {
      final fridayEvening = DateTime(2026, 11, 20, 18);

      expect(
        ReminderScheduler.computeNextOccurrence(
          reminder(ReminderRepeat.workingDays),
          fridayEvening,
        ),
        DateTime(2026, 11, 23, 8, 30),
      );
      expect(
        ReminderScheduler.computeNextOccurrence(
          reminder(ReminderRepeat.weekends),
          fridayEvening,
        ),
        DateTime(2026, 11, 21, 8, 30),
      );
    });

    test('treats the selected minute as passed once that minute starts', () {
      expect(
        ReminderScheduler.computeNextOccurrence(
          reminder(ReminderRepeat.daily),
          DateTime(2026, 11, 16, 8, 30, 1),
        ),
        DateTime(2026, 11, 17, 8, 30),
      );
    });
  });
}
