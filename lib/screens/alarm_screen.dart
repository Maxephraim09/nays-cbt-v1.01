import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/database/nays_cbt_database.dart';
import '../services/reminder_service.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({this.reminderId, super.key});

  final String? reminderId;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with WidgetsBindingObserver {
  static const _alarmWindowChannel = MethodChannel(
    'com.nays.nays_mobile/alarm_window',
  );

  String? _reminderTitle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enforceFullScreenAlarmWindow());
    _loadReminder();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_enforceFullScreenAlarmWindow());
    }
  }

  Future<void> _loadReminder() async {
    final id = widget.reminderId;
    if (id == null || id.isEmpty) {
      return;
    }
    final reminder = await NaysCbtDatabase.instance.getReminder(id);
    if (!mounted) return;
    setState(() {
      _reminderTitle = reminder == null
          ? 'Study Reminder'
          : (reminder['title'] as String? ?? 'Study Reminder');
    });
  }

  Future<void> _dismissAlarm() async {
    final id = widget.reminderId;
    if (id != null && id.isNotEmpty) {
      final reminderMap = await NaysCbtDatabase.instance.getReminder(id);
      if (reminderMap != null) {
        final reminder = ReminderRecord.fromMap(reminderMap);
        if (reminder.repeat == ReminderRepeat.once) {
          await NaysCbtDatabase.instance.updateReminderEnabled(id, false);
          await ReminderScheduler().cancelReminder(id);
        }
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_restoreAlarmWindow());
    }
    super.dispose();
  }

  Future<void> _enforceFullScreenAlarmWindow() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    try {
      await _alarmWindowChannel.invokeMethod<void>('setAlarmWindowFlags');
    } on MissingPluginException {
      // The alarm window channel is only registered by the Android runner.
    } on PlatformException catch (error) {
      debugPrint('Could not enable alarm window flags: $error');
    }
  }

  Future<void> _restoreAlarmWindow() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await _clearAlarmWindowFlags();
  }

  Future<void> _clearAlarmWindowFlags() async {
    try {
      await _alarmWindowChannel.invokeMethod<void>('clearAlarmWindowFlags');
    } on MissingPluginException {
      // The alarm window channel is only registered by the Android runner.
    } on PlatformException catch (error) {
      debugPrint('Could not clear alarm window flags: $error');
    }
  }

  Future<void> _snoozeAlarm() async {
    final id = widget.reminderId;
    if (id != null && id.isNotEmpty) {
      final reminderMap = await NaysCbtDatabase.instance.getReminder(id);
      if (reminderMap != null) {
        final reminder = ReminderRecord.fromMap(reminderMap);
        final snoozedTime = DateTime.now().add(const Duration(minutes: 10));
        final scheduler = ReminderScheduler();
        await scheduler.scheduleSnooze(reminder, snoozedTime);
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _startReading() async {
    await _dismissAlarm();
    await launchUrl(Uri.parse('https://www.google.com/search?q=study+plan'));
  }

  @override
  Widget build(BuildContext context) {
    final title = _reminderTitle ?? 'Study Reminder';
    return Scaffold(
      backgroundColor: const Color(0xFF071A17),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.alarm_rounded, size: 70, color: Colors.white),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'It is time to study.',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _startReading,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10A982),
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('START READING'),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _snoozeAlarm,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5B57FF),
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.snooze_rounded),
                label: const Text('SNOOZE 10 MINS'),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: _dismissAlarm,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text('DISMISS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
