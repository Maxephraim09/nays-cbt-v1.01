import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../core/database/nays_cbt_database.dart';
import '../services/reminder_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final ReminderScheduler _scheduler = ReminderScheduler();
  final TextEditingController _titleController = TextEditingController();
  final AudioPlayer _previewPlayer = AudioPlayer();
  final List<String> _ringtoneOptions = const ['default', 'ringtone_1'];

  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  ReminderRepeat _repeat = ReminderRepeat.once;
  String _selectedRingtone = 'default';
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String? _editingId;
  ReminderRecord? _editingReminder;
  String? _loadError;
  String? _scheduleError;
  bool? _fullScreenIntentPermissionGranted;
  List<ReminderRecord> _reminders = const [];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    try {
      final rows = await NaysCbtDatabase.instance.getReminderList();
      final reminders = rows
          .map(ReminderRecord.fromMap)
          .toList(growable: false);
      String? scheduleError;
      try {
        await _scheduler.rescheduleAllEnabled();
      } on Exception catch (error) {
        scheduleError = error.toString();
      }
      final fullScreenPermissionGranted =
          _scheduler.fullScreenIntentPermissionGranted;
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _loading = false;
        _loadError = null;
        _scheduleError = scheduleError;
        _fullScreenIntentPermissionGranted = fullScreenPermissionGranted;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _saveReminder() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reminder title.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final reminder = ReminderRecord(
        id: _editingId ?? now.microsecondsSinceEpoch.toString(),
        title: title,
        time: _selectedTime,
        repeat: _repeat,
        ringtone: _selectedRingtone,
        enabled: _editingReminder?.enabled ?? true,
        nextOccurrence: _editingReminder?.nextOccurrence,
        createdAt: _editingReminder?.createdAt ?? now,
        updatedAt: now,
      );
      await NaysCbtDatabase.instance.upsertReminder(reminder.toMap());

      String? schedulingError;
      try {
        if (reminder.enabled) {
          await _scheduler.scheduleReminder(reminder);
        } else {
          await _scheduler.cancelReminder(reminder.id);
        }
      } on Exception catch (error) {
        schedulingError = error.toString();
      }

      await _loadReminders();
      if (!mounted) return;
      if (schedulingError == null) {
        _resetForm();
      } else {
        setState(() {
          _editing = true;
          _editingId = reminder.id;
          _editingReminder = reminder;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            schedulingError == null
                ? 'Reminder saved successfully.'
                : 'Reminder saved, but the alarm could not be scheduled. '
                      'Check notification and exact-alarm permissions. '
                      'Details: $schedulingError',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save reminder: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteReminder(String id) async {
    try {
      await _scheduler.cancelReminder(id);
      await NaysCbtDatabase.instance.clearReminderAlarm(id);
      await _loadReminders();
      if (!mounted) return;
      if (_editingId == id) _resetForm();
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete reminder: $error')),
      );
    }
  }

  Future<void> _toggleReminder(ReminderRecord reminder) async {
    final updated = reminder.copyWith(
      enabled: !reminder.enabled,
      updatedAt: DateTime.now(),
    );
    try {
      await NaysCbtDatabase.instance.upsertReminder(updated.toMap());
      if (updated.enabled) {
        await _scheduler.scheduleReminder(updated);
      } else {
        await _scheduler.cancelReminder(updated.id);
      }
      await _loadReminders();
    } on Exception catch (error) {
      await _loadReminders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update reminder alarm: $error')),
      );
    }
  }

  Future<void> _editReminder(ReminderRecord reminder) async {
    setState(() {
      _editing = true;
      _editingId = reminder.id;
      _editingReminder = reminder;
      _titleController.text = reminder.title;
      _selectedTime = reminder.time;
      _repeat = reminder.repeat;
      _selectedRingtone = reminder.ringtone;
    });
  }

  void _resetForm() {
    setState(() {
      _titleController.clear();
      _selectedTime = const TimeOfDay(hour: 8, minute: 0);
      _repeat = ReminderRepeat.once;
      _selectedRingtone = 'default';
      _editing = false;
      _editingId = null;
      _editingReminder = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load reminders: $_loadError'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _loadError = null;
                        });
                        _loadReminders();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                if (_scheduleError != null) ...[
                  _buildScheduleWarning(),
                  const SizedBox(height: 16),
                ],
                if (_fullScreenIntentPermissionGranted == false) ...[
                  _buildFullScreenWarning(),
                  const SizedBox(height: 16),
                ],
                _buildForm(),
                const SizedBox(height: 20),
                if (_reminders.isEmpty)
                  _buildEmptyState()
                else
                  ..._reminders.map(_buildReminderTile),
              ],
            ),
    );
  }

  Widget _buildForm() => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editing ? 'Edit reminder' : 'Create reminder',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Reminder Title',
              border: OutlineInputBorder(),
              hintText: 'Read Mathematics',
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reminder Time'),
            trailing: Text(_selectedTime.format(context)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (picked != null && mounted) {
                setState(() => _selectedTime = picked);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReminderRepeat>(
            key: const ValueKey('reminder-repeat-dropdown'),
            initialValue: _repeat,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Repeat'),
            items: ReminderRepeat.values
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(option.label),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _repeat = value);
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('reminder-ringtone-dropdown'),
            initialValue: _selectedRingtone,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Ringtone',
              helperText: 'Preview plays when you select a ringtone.',
            ),
            items: _ringtoneOptions
                .map(
                  (tone) => DropdownMenuItem(
                    value: tone,
                    child: Text(_toneLabel(tone)),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _selectedRingtone = value);
                    unawaited(_previewRingtone(value));
                  },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveReminder,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.alarm_add_rounded),
              label: Text(
                _saving
                    ? 'Saving...'
                    : _editing
                    ? 'Update Reminder'
                    : 'Set Reminder',
              ),
            ),
          ),
          if (_editing) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _saving ? null : _resetForm,
                child: const Text('Cancel editing'),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildEmptyState() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.notifications_off_rounded, size: 40),
          const SizedBox(height: 12),
          const Text('No reminders yet'),
          const SizedBox(height: 6),
          Text(
            'Create a reminder for your reading or revision session.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );

  Widget _buildScheduleWarning() => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        'Some alarms could not be activated. Check notification and exact '
        'alarm permissions, then reopen this screen. Details: $_scheduleError',
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    ),
  );

  Widget _buildFullScreenWarning() => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Full-screen alarm access is off. Alarms can still notify you, '
            'but Android may not open the alarm screen over the lock screen.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _requestFullScreenIntentPermission,
            child: const Text('Enable full-screen alarms'),
          ),
        ],
      ),
    ),
  );

  Future<void> _requestFullScreenIntentPermission() async {
    try {
      final granted = await _scheduler.requestFullScreenIntentPermission();
      if (!mounted) return;
      setState(() => _fullScreenIntentPermissionGranted = granted);
      if (granted != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow NAYS to use full-screen notifications in Android settings.',
            ),
          ),
        );
      }
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update full-screen access: $error')),
      );
    }
  }

  Future<void> _previewRingtone(String ringtone) async {
    final assetPath = ringtone == 'ringtone_1'
        ? 'ringtones/ringtone_1.mp3'
        : 'ringtones/defualt.mp3';
    try {
      await _previewPlayer.stop();
      await _previewPlayer.play(AssetSource(assetPath));
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play ringtone preview: $error')),
      );
    }
  }

  Widget _buildReminderTile(ReminderRecord reminder) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      title: Text(reminder.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${reminder.time.format(context)} • ${reminder.repeat.label}'),
          Text('Ringtone: ${_toneLabel(reminder.ringtone)}'),
          Text(reminder.enabled ? 'Enabled' : 'Disabled'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: reminder.enabled,
            onChanged: (_) => _toggleReminder(reminder),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _editReminder(reminder),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            onPressed: () => _deleteReminder(reminder.id),
          ),
        ],
      ),
    ),
  );

  String _toneLabel(String tone) {
    switch (tone) {
      case 'default':
        return 'Default Alarm';
      case 'ringtone_1':
        return 'Alarm Tone 1';
      default:
        return tone;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    unawaited(_previewPlayer.dispose());
    super.dispose();
  }
}
