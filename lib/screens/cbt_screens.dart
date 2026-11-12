import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../auth_user_profile.dart';
import '../app_state.dart';
import '../services/firestore_models.dart';
import '../services/firestore_service.dart';
import '../services/offline_exam_store.dart';
import '../services/jamb_simulation_config.dart';
import '../theme/app_theme.dart';
import '../widgets/nays_widgets.dart';
import 'info_screens.dart';

class CbtHubScreen extends StatefulWidget {
  const CbtHubScreen({
    required this.controller,
    required this.onOpen,
    this.profile,
    this.service,
    this.isActive = true,
    super.key,
  });
  final DemoAppController controller;
  final ValueChanged<Widget> onOpen;
  final AuthUserProfile? profile;
  final FirestoreCbtService? service;

  /// The main shell keeps this screen mounted in an IndexedStack.
  final bool isActive;

  @override
  State<CbtHubScreen> createState() => _CbtHubScreenState();
}

class _CbtHubScreenState extends State<CbtHubScreen> {
  late final FirestoreCbtService _service =
      widget.service ?? FirestoreCbtService();
  List<NaysSubject> _subjects = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _loadError;
  String? _offlineError;
  OfflineExamAttempt? _activeAttempt;
  List<OfflineExamAttempt> _pendingSubmissions = const [];
  StreamSubscription<List<NaysSubject>>? _registeredSubjectsSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _watchSubjects();
      unawaited(_loadLocalAttempts());
    }
  }

  @override
  void didUpdateWidget(covariant CbtHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _watchSubjects();
      unawaited(_loadLocalAttempts());
    }
  }

  void _watchSubjects() {
    _registeredSubjectsSubscription?.cancel();
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    _registeredSubjectsSubscription = _service.watchRegisteredSubjects().listen(
      (subjects) {
        final sortedSubjects = [...subjects]
          ..sort(
            (a, b) => a.subjectName.toLowerCase().compareTo(
              b.subjectName.toLowerCase(),
            ),
          );
        if (!mounted) return;
        final nameCounts = <String, int>{};
        for (final subject in sortedSubjects) {
          nameCounts.update(
            subject.subjectName,
            (duplicateCount) => duplicateCount + 1,
            ifAbsent: () => 1,
          );
        }
        widget.controller.setRegisteredSubjects({
          for (final subject in sortedSubjects)
            subject.subjectId: _registeredSubjectLabel(
              subject,
              nameCounts[subject.subjectName]!,
            ),
        });
        setState(() {
          _subjects = sortedSubjects;
          _isLoading = false;
          _hasLoaded = true;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _loadError = error is FirebaseException
              ? error.message ?? 'Firestore error: ${error.code}'
              : error.toString();
          _isLoading = false;
        });
      },
    );
  }

  String _registeredSubjectLabel(NaysSubject subject, int sameNameCount) {
    if (sameNameCount < 2) return subject.subjectName;
    final qualifiers = [
      subject.educationLevel,
      subject.subjectCode,
    ].where((value) => value.trim().isNotEmpty).join(' · ');
    return '${subject.subjectName} (${qualifiers.isEmpty ? subject.subjectId : qualifiers})';
  }

  Future<void> _loadSubjects() async {
    try {
      await _service.watchRegisteredSubjects().first;
      await _loadLocalAttempts();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message ?? 'Firestore error: ${error.code}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    }
  }

  Future<void> _loadLocalAttempts() async {
    try {
      final active = await _service.loadActiveExam();
      final pending = await _service.loadPendingSubmissions();
      if (!mounted) return;
      setState(() {
        _activeAttempt = active;
        _pendingSubmissions = pending;
        _offlineError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _offlineError =
            'Saved exam data could not be opened on this device. Retry; '
            'the saved data has not been deleted.',
      );
    }
  }

  void _resumeExam(OfflineExamAttempt attempt) {
    widget.controller.restoreAnswers(attempt.answers);
    widget.onOpen(
      ExamScreen(
        controller: widget.controller,
        service: _service,
        session: attempt.session,
        initialQuestionIndex: attempt.currentQuestionIndex,
        profile: widget.profile,
      ),
    );
  }

  Future<void> _syncPendingSubmissions() async {
    if (!_service.hasAuthenticatedUser) return;
    try {
      final synchronized = await _service.syncPendingSubmissions();
      await _loadLocalAttempts();
      if (!mounted || synchronized.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${synchronized.length} offline submission(s) synced for verification.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final permissionDenied =
          error.toString().toLowerCase().contains('permission-denied') ||
          error.toString().toLowerCase().contains(
            'missing or insufficient permissions',
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permissionDenied
                ? 'Submission remains saved on this device. Cloud verification '
                      'is blocked by account permissions; check the deployed Firestore rules.'
                : 'Submission remains saved on this device. Cloud verification '
                      'will retry when sync is available.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _registeredSubjectsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _loadSubjects,
    child: ListView(
      key: const ValueKey('cbt-hub-content'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
      children: [
        const PageHeading(
          eyebrow: 'COMPUTER-BASED PRACTICE',
          title: 'CBT centre',
          subtitle:
              'Practice and exam questions are read from the question bank installed on this device.',
        ),
        const SizedBox(height: 19),
        if (_offlineError != null) ...[
          _FirestoreLoadError(
            message: _offlineError!,
            onRetry: _loadLocalAttempts,
          ),
          const SizedBox(height: 10),
        ],
        if (_activeAttempt case final attempt?) ...[
          SurfaceCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.restore_rounded,
                color: AppTheme.forest,
              ),
              title: Text('Resume ${attempt.session.subjectName}'),
              subtitle: const Text(
                'Your encrypted progress is saved on this device.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _resumeExam(attempt),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_pendingSubmissions.isNotEmpty) ...[
          SurfaceCard(
            child: Column(
              children: [
                for (final attempt in _pendingSubmissions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.cloud_upload_outlined,
                      color: AppTheme.forest,
                    ),
                    title: Text('${attempt.session.subjectName} result'),
                    subtitle: Text(
                      _service.hasAuthenticatedUser
                          ? 'Saved on this device and waiting for verification.'
                          : 'Saved on this device. Sign in online to request verification.',
                    ),
                  ),
                if (_service.hasAuthenticatedUser)
                  OutlinedButton.icon(
                    onPressed: _syncPendingSubmissions,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Retry offline submissions'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SectionLabel('Registered subjects'),
        const SizedBox(height: 9),
        SurfaceCard(
          child: Column(
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text('Loading subjects from Firestore…'),
                      ],
                    ),
                  ),
                )
              else if (_loadError != null)
                _FirestoreLoadError(
                  message: _loadError!,
                  onRetry: _loadSubjects,
                )
              else if (_hasLoaded && _subjects.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'You have not registered for any active subjects yet.',
                    textAlign: TextAlign.center,
                  ),
                )
              else if (!_hasLoaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Your registered subjects will appear here.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._subjects.map(
                  (subject) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEAF2EC),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: AppTheme.forest,
                      ),
                    ),
                    title: Text(subject.subjectName),
                    subtitle: Text(
                      '${subject.subjectCode.isEmpty ? subject.category : subject.subjectCode} · ${subject.educationLevel}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => widget.onOpen(
                      CbtPreparationScreen(
                        controller: widget.controller,
                        service: _service,
                        selectedSubject: subject,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('cbt-register-subjects'),
          onPressed: () => widget.onOpen(
            SubjectRegistrationScreen(
              controller: widget.controller,
              service: _service,
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Register subjects'),
        ),
        const SizedBox(height: 14),
        ListTile(
          key: const ValueKey('cbt-settings'),
          tileColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: const Icon(Icons.tune_rounded, color: AppTheme.forest),
          title: const Text('CBT settings'),
          subtitle: const Text('Persistent examination preferences'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => widget.onOpen(
            CbtSettingsScreen(controller: widget.controller, service: _service),
          ),
        ),
        const SizedBox(height: 10),
        ListTile(
          key: const ValueKey('cbt-jamb-settings'),
          tileColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: const Icon(Icons.fact_check_rounded, color: AppTheme.forest),
          title: const Text('JAMB Simulation Settings'),
          subtitle: const Text('Choose your four examination subjects'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () =>
              widget.onOpen(JambSimulationSettingsScreen(service: _service)),
        ),
        const SizedBox(height: 10),
        ListTile(
          key: const ValueKey('cbt-exam-history'),
          tileColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: const Icon(Icons.history_rounded, color: AppTheme.forest),
          title: const Text('Exam history'),
          subtitle: const Text('Review your server-graded results'),
          onTap: () => widget.onOpen(HistoryScreen(service: _service)),
        ),
      ],
    ),
  );
}

class ExamsSettingsScreen extends StatelessWidget {
  const ExamsSettingsScreen({
    required this.controller,
    required this.service,
    required this.onOpen,
    super.key,
  });

  final DemoAppController controller;
  final FirestoreCbtService service;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Exams settings')),
    body: ListView(
      key: const ValueKey('exams-settings-content'),
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeading(
          eyebrow: 'EXAMINATION PREFERENCES',
          title: 'Exams settings',
          subtitle: 'Manage subjects and preferences for your examinations.',
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                key: const ValueKey('exam-settings-register-subjects'),
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Register subjects'),
                subtitle: const Text('Choose subjects for practice'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onOpen(
                  SubjectRegistrationScreen(
                    controller: controller,
                    service: service,
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                key: const ValueKey('exam-settings-cbt'),
                leading: const Icon(Icons.tune_rounded),
                title: const Text('CBT settings'),
                subtitle: const Text('Difficulty, duration and exam options'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onOpen(
                  CbtSettingsScreen(controller: controller, service: service),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                key: const ValueKey('exam-settings-jamb'),
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('JAMB simulation settings'),
                subtitle: const Text('Choose your four examination subjects'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    onOpen(JambSimulationSettingsScreen(service: service)),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                key: const ValueKey('exam-settings-history'),
                leading: const Icon(Icons.history_rounded),
                title: const Text('Exam history'),
                subtitle: const Text('Review completed examinations'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onOpen(HistoryScreen(service: service)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FirestoreLoadError extends StatelessWidget {
  const _FirestoreLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.cloud_off_outlined, color: Colors.redAccent, size: 32),
      const SizedBox(height: 8),
      const Text(
        'Could not load Firestore data.',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry'),
      ),
    ],
  );
}

class SubjectRegistrationScreen extends StatefulWidget {
  const SubjectRegistrationScreen({
    required this.controller,
    required this.service,
    super.key,
  });
  final DemoAppController controller;
  final FirestoreCbtService service;
  @override
  State<SubjectRegistrationScreen> createState() =>
      _SubjectRegistrationScreenState();
}

class _SubjectRegistrationScreenState extends State<SubjectRegistrationScreen> {
  String _query = '';
  String? _busySubjectId;

  Future<void> _toggleSubject(NaysSubject subject, bool registered) async {
    setState(() => _busySubjectId = subject.subjectId);
    try {
      if (registered) {
        await widget.service.unregisterSubject(subject.subjectId);
      } else {
        await widget.service.registerSubject(subject.subjectId);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update registration: $error')),
      );
    } finally {
      if (mounted) setState(() => _busySubjectId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Register subjects')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Column(
            children: [
              TextField(
                key: const ValueKey('subject-search'),
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search subjects',
                ),
              ),
              const SizedBox(height: 12),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Selected subjects',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${widget.controller.subjects.length}',
                      style: const TextStyle(
                        color: AppTheme.forest,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'registered',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<NaysSubject>>(
            stream: widget.service.watchQuestionBankSubjects(),
            builder: (context, subjectsSnapshot) {
              if (subjectsSnapshot.hasError) {
                return Center(
                  child: _FirestoreLoadError(
                    message: subjectsSnapshot.error.toString(),
                    onRetry: () => setState(() {}),
                  ),
                );
              }
              if (!subjectsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return StreamBuilder<List<NaysSubject>>(
                stream: widget.service.watchRegisteredSubjects(),
                builder: (context, registrationSnapshot) {
                  if (registrationSnapshot.hasError) {
                    return Center(
                      child: _FirestoreLoadError(
                        message: registrationSnapshot.error.toString(),
                        onRetry: () => setState(() {}),
                      ),
                    );
                  }
                  if (!registrationSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final registeredIds = registrationSnapshot.data!
                      .map((subject) => subject.subjectId)
                      .toSet();
                  final query = _query.trim().toLowerCase();
                  final visible = subjectsSnapshot.data!
                      .where(
                        (subject) =>
                            query.isEmpty ||
                            subject.subjectName.toLowerCase().contains(query) ||
                            subject.subjectCode.toLowerCase().contains(query),
                      )
                      .toList(growable: false);
                  if (visible.isEmpty) {
                    return const Center(
                      child: Text('No active subjects are available.'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final subject = visible[index];
                      final registered = registeredIds.contains(
                        subject.subjectId,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SurfaceCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 3,
                          ),
                          child: CheckboxListTile(
                            value: registered,
                            onChanged: _busySubjectId == subject.subjectId
                                ? null
                                : (_) => _toggleSubject(subject, registered),
                            controlAffinity: ListTileControlAffinity.trailing,
                            title: Text(
                              subject.subjectName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${subject.subjectCode} · ${subject.description}',
                            ),
                            secondary: const Icon(
                              Icons.menu_book_outlined,
                              color: AppTheme.forest,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: PrimaryButton(
              label: 'Done',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ],
    ),
  );
}

class CbtSettingsScreen extends StatefulWidget {
  const CbtSettingsScreen({
    required this.controller,
    required this.service,
    super.key,
  });
  final DemoAppController controller;
  final FirestoreCbtService service;
  @override
  State<CbtSettingsScreen> createState() => _CbtSettingsScreenState();
}

class _CbtSettingsScreenState extends State<CbtSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final preferences = await widget.service.fetchCbtPreferences();
      if (!mounted) return;
      widget.controller.updateSettings(
        nextDifficulty: preferences.difficulty,
        nextDuration: preferences.durationMinutes,
        nextQuestionCount: preferences.questionsPerExam,
        nextShuffle: preferences.shuffleQuestions,
        nextShuffleAnswers: preferences.shuffleAnswers,
        nextShowExplanations: preferences.showExplanations,
        nextNegativeMarking: preferences.negativeMarking,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final state = widget.controller;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.service.saveCbtPreferences(
        NaysCbtPreferences(
          difficulty: state.difficulty,
          durationMinutes: state.durationMinutes,
          questionsPerExam: state.questionsPerExam,
          shuffleQuestions: state.shuffleQuestions,
          shuffleAnswers: state.shuffleAnswers,
          showExplanations: state.showExplanations,
          negativeMarking: state.negativeMarking,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preferences saved on this device and backed up when online.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('CBT settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: _FirestoreLoadError(message: _error!, onRetry: _load),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const PageHeading(
                  eyebrow: 'SESSION PREFERENCES',
                  title: 'Make it yours',
                  subtitle:
                      'Preferences are saved locally and backed up when online.',
                ),
                const SizedBox(height: 18),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Difficulty',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 9),
                      DropdownButtonFormField<String>(
                        initialValue: state.difficulty,
                        items: ['Easy', 'Medium', 'Hard', 'Mixed']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => state.updateSettings(nextDifficulty: value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Examination duration',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '${state.durationMinutes} min',
                            style: const TextStyle(
                              color: AppTheme.forest,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: state.durationMinutes.toDouble(),
                        min: 15,
                        max: 120,
                        divisions: 7,
                        label: '${state.durationMinutes} min',
                        onChanged: (value) => setState(
                          () =>
                              state.updateSettings(nextDuration: value.round()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Maximum questions per examination',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '${state.questionsPerExam}',
                            style: const TextStyle(
                              color: AppTheme.forest,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: state.questionsPerExam.toDouble(),
                        min: NaysCbtPreferences.minimumQuestionsPerExam
                            .toDouble(),
                        max: NaysCbtPreferences.maximumQuestionsPerExam
                            .toDouble(),
                        divisions:
                            (NaysCbtPreferences.maximumQuestionsPerExam -
                                NaysCbtPreferences.minimumQuestionsPerExam) ~/
                            5,
                        label: '${state.questionsPerExam}',
                        onChanged: (value) => setState(
                          () => state.updateSettings(
                            nextQuestionCount: value.round(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SurfaceCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Shuffle questions',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Randomize the question order for each attempt',
                        ),
                        value: state.shuffleQuestions,
                        onChanged: (value) => setState(
                          () => state.updateSettings(nextShuffle: value),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Shuffle answer options',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        value: state.shuffleAnswers,
                        onChanged: (value) => setState(
                          () => state.updateSettings(nextShuffleAnswers: value),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Show explanations after submission',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        value: state.showExplanations,
                        onChanged: (value) => setState(
                          () =>
                              state.updateSettings(nextShowExplanations: value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 17),
                PrimaryButton(
                  label: _isSaving ? 'Saving…' : 'Save preferences',
                  onPressed: _isSaving ? null : _save,
                ),
              ],
            ),
    );
  }
}

class JambSimulationSettingsScreen extends StatefulWidget {
  const JambSimulationSettingsScreen({required this.service, super.key});

  final FirestoreCbtService service;

  @override
  State<JambSimulationSettingsScreen> createState() =>
      _JambSimulationSettingsScreenState();
}

class _JambSimulationSettingsScreenState
    extends State<JambSimulationSettingsScreen> {
  List<NaysSubject> _additionalSubjects = const [];
  Set<String> _selectedSubjectIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final subjects = await widget.service.watchQuestionBankSubjects().first;
      final savedIds = await widget.service.loadJambSubjectIds();
      final englishFound = subjects.any(
        (subject) => subject.subjectId == JambSimulationConfig.englishSubjectId,
      );
      final names = <String>{};
      final options = subjects
          .where((subject) {
            if (subject.subjectId == JambSimulationConfig.englishSubjectId) {
              return false;
            }
            return names.add(subject.subjectName.trim().toLowerCase());
          })
          .toList(growable: false);
      final availableIds = options.map((subject) => subject.subjectId).toSet();
      if (!mounted) return;
      setState(() {
        _additionalSubjects = options;
        _selectedSubjectIds = JambSimulationConfig.normalizeAdditionalSubjects(
          savedIds.where(availableIds.contains),
        ).take(JambSimulationConfig.additionalSubjectCount).toSet();
        _isLoading = false;
        if (!englishFound) {
          _error =
              'English Language is missing from the installed question bank.';
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not load the installed question bank: $error';
        });
      }
    }
  }

  void _toggleSubject(String subjectId, bool selected) {
    setState(() {
      if (selected) {
        if (_selectedSubjectIds.length <
            JambSimulationConfig.additionalSubjectCount) {
          _selectedSubjectIds.add(subjectId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Choose only three additional subjects.'),
            ),
          );
        }
      } else {
        _selectedSubjectIds.remove(subjectId);
      }
    });
  }

  Future<void> _save() async {
    final selected = [
      JambSimulationConfig.englishSubjectId,
      ..._selectedSubjectIds,
    ];
    final available = {
      JambSimulationConfig.englishSubjectId,
      ..._additionalSubjects.map((subject) => subject.subjectId),
    };
    if (!JambSimulationConfig.isConfigured(
      selected,
      availableSubjectIds: available,
    )) {
      setState(() => _error = 'Select exactly three additional subjects.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.service.saveJambSubjectIds(selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('JAMB subjects saved on this device.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save subjects: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('JAMB Simulation Settings')),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const PageHeading(
                eyebrow: 'JAMB EXAMINATION',
                title: 'Choose your subjects',
                subtitle: 'English Language is compulsory. Select three more.',
              ),
              const SizedBox(height: 16),
              const SurfaceCard(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.lock_outline_rounded),
                  title: Text('JAMB Examination PIN'),
                  subtitle: Text(
                    JambSimulationConfig.examPin,
                    style: TextStyle(
                      color: AppTheme.forest,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const SurfaceCard(
                padding: EdgeInsets.zero,
                child: CheckboxListTile(
                  value: true,
                  onChanged: null,
                  secondary: Icon(Icons.lock_outline_rounded),
                  title: Text('English Language'),
                  subtitle: Text('Compulsory · 60 questions'),
                ),
              ),
              const SizedBox(height: 10),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final subject in _additionalSubjects)
                      CheckboxListTile(
                        key: ValueKey('jamb-subject-${subject.subjectId}'),
                        value: _selectedSubjectIds.contains(subject.subjectId),
                        title: Text(subject.subjectName),
                        subtitle: const Text('40 questions'),
                        onChanged: (selected) => _toggleSubject(
                          subject.subjectId,
                          selected ?? false,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const SurfaceCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Total questions'),
                      trailing: Text('180'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Examination duration'),
                      trailing: Text('2 hours (120 minutes)'),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                label: _isSaving ? 'Saving…' : 'Save subjects',
                icon: Icons.save_outlined,
                onPressed:
                    _isSaving ||
                        _error?.startsWith('English Language is missing') ==
                            true ||
                        _selectedSubjectIds.length !=
                            JambSimulationConfig.additionalSubjectCount
                    ? null
                    : _save,
              ),
            ],
          ),
  );
}

class JambSimulationWaitingScreen extends StatefulWidget {
  const JambSimulationWaitingScreen({
    required this.controller,
    required this.service,
    this.profile,
    super.key,
  });

  final DemoAppController controller;
  final FirestoreCbtService service;
  final AuthUserProfile? profile;

  @override
  State<JambSimulationWaitingScreen> createState() =>
      _JambSimulationWaitingScreenState();
}

class _JambSimulationWaitingScreenState
    extends State<JambSimulationWaitingScreen> {
  final TextEditingController _pinController = TextEditingController();
  List<NaysSubject> _subjects = const [];
  List<String> _selectedSubjectIds = const [];
  bool _isLoading = true;
  bool _isStarting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final subjects = await widget.service.watchQuestionBankSubjects().first;
      final selectedIds = await widget.service.loadJambSubjectIds();
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _selectedSubjectIds = selectedIds;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not load JAMB settings: $error';
        });
      }
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => JambSimulationSettingsScreen(service: widget.service),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _startExam() async {
    final availableIds = _subjects.map((subject) => subject.subjectId);
    if (!JambSimulationConfig.isConfigured(
      _selectedSubjectIds,
      availableSubjectIds: availableIds,
    )) {
      setState(() => _error = 'Configure English and three subjects first.');
      return;
    }
    if (!JambSimulationConfig.isValidPin(_pinController.text)) {
      setState(() => _error = 'The examination PIN is incorrect. Try again.');
      return;
    }
    setState(() {
      _isStarting = true;
      _error = null;
    });
    try {
      if (await widget.service.loadActiveExam() != null) {
        throw StateError(
          'Resume your saved examination before starting another.',
        );
      }
      final session = await widget.service.startJambExam(
        subjectIds: _selectedSubjectIds,
      );
      if (!mounted) return;
      widget.controller.clearAnswers();
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ExamScreen(
            controller: widget.controller,
            service: widget.service,
            session: session,
            profile: widget.profile,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not start examination: $error');
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsById = {
      for (final subject in _subjects) subject.subjectId: subject,
    };
    final configured = JambSimulationConfig.isConfigured(
      _selectedSubjectIds,
      availableSubjectIds: subjectsById.keys,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('JAMB Simulation')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const PageHeading(
                  eyebrow: 'EXAMINATION INSTRUCTIONS',
                  title: 'JAMB Simulation',
                  subtitle: 'Review the details before you begin.',
                ),
                const SizedBox(height: 14),
                const SurfaceCard(
                  child: Text(
                    'The examination contains four selected subjects. English Language is compulsory and has 60 questions; each of your other three subjects has 40 questions. You have 120 minutes. Review your answers before submitting. The examination will end automatically when the timer reaches zero.',
                    style: TextStyle(height: 1.55),
                  ),
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your subjects',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (configured)
                        for (final subjectId in _selectedSubjectIds)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              subjectsById[subjectId]?.subjectName ?? subjectId,
                            ),
                            trailing: Text(
                              '${JambSimulationConfig.questionCountFor(subjectId)} questions',
                            ),
                          )
                      else
                        const Text(
                          'Choose English and three additional subjects.',
                        ),
                      const Divider(),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Total questions'),
                        trailing: Text('180'),
                      ),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Duration'),
                        trailing: Text('2 hours (120 minutes)'),
                      ),
                    ],
                  ),
                ),
                if (!configured) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Configure subjects'),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Examination PIN',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 9),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _isStarting ? 'Starting…' : 'Start Examination',
                  icon: Icons.play_arrow_rounded,
                  onPressed: _isStarting || _isLoading ? null : _startExam,
                ),
              ],
            ),
    );
  }
}

class CbtPreparationScreen extends StatelessWidget {
  const CbtPreparationScreen({
    required this.controller,
    required this.service,
    required this.selectedSubject,
    super.key,
  });
  final DemoAppController controller;
  final FirestoreCbtService service;
  final NaysSubject selectedSubject;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prepare examination')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PageHeading(
            eyebrow: 'EXAMINATION SETUP',
            title: 'Your practice\nsession.',
            subtitle: 'Questions and results are managed securely by NAYS.',
          ),
          const SizedBox(height: 18),
          SurfaceCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.menu_book_outlined,
                    color: AppTheme.forest,
                  ),
                  title: const Text('Registered subject'),
                  subtitle: Text(selectedSubject.subjectName),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.tune_rounded,
                    color: AppTheme.forest,
                  ),
                  title: const Text('Difficulty'),
                  trailing: Text(controller.difficulty),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.timer_outlined,
                    color: AppTheme.forest,
                  ),
                  title: const Text('Duration'),
                  trailing: Text('${controller.durationMinutes} min'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.quiz_outlined,
                    color: AppTheme.forest,
                  ),
                  title: const Text('Question bank'),
                  trailing: const Text('Installed SQLite bank'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.format_list_numbered_rounded,
                    color: AppTheme.forest,
                  ),
                  title: const Text('Maximum questions per session'),
                  trailing: Text('${controller.questionsPerExam}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A few reminders',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 10),
                Text(
                  '• Questions are loaded from the installed SQLite bank.\n• Use the palette to move between examination questions.\n• Answers and results are saved locally.',
                  style: TextStyle(color: AppTheme.muted, height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Practice offline'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PracticeScreen(service: service, subject: selectedSubject),
              ),
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Start examination',
            icon: Icons.play_arrow_rounded,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CbtAccessScreen(
                  controller: controller,
                  service: service,
                  selectedSubject: selectedSubject,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PracticeSubjectsScreen extends StatelessWidget {
  const PracticeSubjectsScreen({required this.service, super.key});

  final FirestoreCbtService service;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Practice'),
      actions: [
        IconButton(
          tooltip: 'Practice history',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PracticeHistoryScreen(service: service),
            ),
          ),
          icon: const Icon(Icons.history_rounded),
        ),
      ],
    ),
    body: StreamBuilder<List<NaysSubject>>(
      stream: service.watchQuestionBankSubjects(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load the local subjects: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final subjects = snapshot.data!;
        if (subjects.isEmpty) {
          return const Center(
            child: Text('The bundled question bank has not been installed.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const PageHeading(
              eyebrow: 'AVAILABLE OFFLINE',
              title: 'Choose a subject',
              subtitle:
                  'Questions and practice results are stored on this device.',
            ),
            const SizedBox(height: 16),
            for (final subject in subjects)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEAF2EC),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: AppTheme.forest,
                      ),
                    ),
                    title: Text(
                      subject.subjectName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      subject.description.isEmpty
                          ? subject.subjectCode
                          : subject.description,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PracticeScreen(service: service, subject: subject),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    required this.service,
    required this.subject,
    super.key,
  });

  final FirestoreCbtService service;
  final NaysSubject subject;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  CbtExamSession? _session;
  Map<String, Object?>? _result;
  Object? _loadError;
  List<String> _topics = const [];
  String _difficulty = 'Mixed';
  String? _topic;
  int _questionCount = 10;
  int _availableCount = 0;
  bool _isPreparing = true;
  bool _isStarting = false;
  int _index = 0;
  Object? _answer;
  bool _isAnswered = false;
  bool _isComplete = false;
  DateTime? _sessionStartedAt;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareSetup());
  }

  Future<void> _prepareSetup() async {
    setState(() {
      _loadError = null;
      _isPreparing = true;
    });
    try {
      final preferences = await widget.service.fetchCbtPreferences();
      final topics = await widget.service.getPracticeTopics(
        widget.subject.subjectId,
      );
      if (!mounted) return;
      setState(() {
        _difficulty = preferences.difficulty;
        _questionCount = preferences.questionsPerExam < 1
            ? 10
            : preferences.questionsPerExam;
        _topics = topics;
        _isPreparing = false;
      });
      await _refreshAvailability();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error;
          _isPreparing = false;
        });
      }
    }
  }

  Future<void> _refreshAvailability() async {
    final available = await widget.service.getAvailablePracticeQuestionCount(
      subjectId: widget.subject.subjectId,
      difficulty: _difficulty,
      topic: _topic,
    );
    if (!mounted) return;
    setState(() {
      _availableCount = available;
      if (available > 0 && _questionCount > available) {
        _questionCount = available;
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _isStarting = true;
    });
    try {
      final session = await widget.service.loadPracticeSession(
        subjectId: widget.subject.subjectId,
        difficulty: _difficulty,
        questionCount: _questionCount,
        topic: _topic,
      );
      if (mounted) {
        setState(() {
          _session = session;
          _sessionStartedAt = DateTime.now();
          _result = null;
          _isComplete = false;
          _index = 0;
          _answer = null;
          _isAnswered = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _selectOption(String optionKey) async {
    if (_isAnswered || _session == null) return;
    final question = _session!.questions[_index];
    Object nextAnswer = optionKey;
    if (question.questionType == 'multiple_select') {
      final selected = (_answer as List<String>? ?? <String>[]).toSet();
      if (!selected.add(optionKey)) selected.remove(optionKey);
      nextAnswer = selected.toList()..sort();
    }
    setState(() => _answer = nextAnswer);
    try {
      await widget.service.savePracticeAnswer(
        sessionId: _session!.sessionId,
        questionId: question.questionId,
        selectedAnswer: nextAnswer,
      );
      if (mounted && question.questionType != 'multiple_select') {
        setState(() => _isAnswered = true);
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _checkMultipleSelect() async {
    if (_answer == null || (_answer as List).isEmpty) return;
    setState(() => _isAnswered = true);
  }

  bool get _isCorrect {
    final question = _session!.questions[_index];
    if (_answer is List && question.correctAnswer is List) {
      final actual = (_answer as List).map((value) => value.toString()).toList()
        ..sort();
      final expected =
          (question.correctAnswer as List)
              .map((value) => value.toString())
              .toList()
            ..sort();
      return actual.toString() == expected.toString();
    }
    return _answer?.toString() == question.correctAnswer?.toString();
  }

  Future<void> _next() async {
    final session = _session!;
    if (_index == session.questions.length - 1) {
      try {
        final result = await widget.service.completePracticeSession(
          sessionId: session.sessionId,
          timeSpentSeconds: DateTime.now()
              .difference(_sessionStartedAt ?? session.startedAt)
              .inSeconds,
        );
        if (mounted) {
          setState(() {
            _result = result;
            _isComplete = true;
          });
        }
      } catch (error) {
        if (mounted) setState(() => _loadError = error);
      }
      return;
    }
    setState(() {
      _index++;
      _answer = null;
      _isAnswered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.subject.subjectName} practice')),
      body: _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Offline practice could not continue: $_loadError',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _session == null ? _prepareSetup : _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : session == null
          ? _isPreparing
                ? const Center(child: CircularProgressIndicator())
                : _buildSetup()
          : _isComplete
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 52,
                      color: AppTheme.forest,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Practice complete',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Score: ${(_result?['percentage'] as num?)?.toStringAsFixed(0) ?? '0'}% '
                      '(${_result?['correct_answers'] ?? 0}/${session.questions.length})',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PracticeReviewScreen(
                            service: widget.service,
                            sessionId: session.sessionId,
                            subjectName: widget.subject.subjectName,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Review answers and explanations'),
                    ),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Practise again'),
                    ),
                  ],
                ),
              ),
            )
          : _buildQuestion(session),
    );
  }

  Widget _buildSetup() {
    final counts =
        <int>{
            5,
            10,
            20,
            30,
            50,
            100,
          }.where((questionCount) => questionCount <= _availableCount).toList()
          ..sort();
    if (_availableCount > 0 && !counts.contains(_availableCount)) {
      counts.add(_availableCount);
      counts.sort();
    }
    if (_availableCount > 0 && !counts.contains(_questionCount)) {
      counts.add(_questionCount);
      counts.sort();
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeading(
          eyebrow: 'PRACTICE SETTINGS',
          title: widget.subject.subjectName,
          subtitle: 'Choose how many local questions you want to practise.',
        ),
        const SizedBox(height: 18),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _difficulty,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: const ['Easy', 'Medium', 'Hard', 'Mixed']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _difficulty = value);
                  unawaited(_refreshAvailability());
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _topic ?? '',
                decoration: const InputDecoration(labelText: 'Topic'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All topics')),
                  ..._topics.map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  ),
                ],
                onChanged: (value) {
                  setState(
                    () =>
                        _topic = value == null || value.isEmpty ? null : value,
                  );
                  unawaited(_refreshAvailability());
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: counts.contains(_questionCount)
                    ? _questionCount
                    : counts.isEmpty
                    ? null
                    : counts.last,
                decoration: const InputDecoration(
                  labelText: 'Number of questions',
                ),
                items: counts
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text('$value')),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _questionCount = value);
                },
              ),
              const SizedBox(height: 10),
              Text(
                widget.subject.subjectId == 'yungur'
                    ? 'Question bank awaiting the official Yungur source document.'
                    : '$_availableCount eligible questions available offline.',
                style: const TextStyle(color: AppTheme.muted),
              ),
            ],
          ),
        ),
        if (_loadError != null) ...[
          const SizedBox(height: 12),
          Text(
            'Could not read the local question bank: $_loadError',
            style: const TextStyle(color: Colors.red),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Start practice',
          icon: Icons.play_arrow_rounded,
          onPressed:
              _isStarting ||
                  _availableCount == 0 ||
                  _questionCount > _availableCount
              ? null
              : _load,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PracticeHistoryScreen(service: widget.service),
            ),
          ),
          icon: const Icon(Icons.history_rounded),
          label: const Text('View practice history'),
        ),
      ],
    );
  }

  Widget _buildQuestion(CbtExamSession session) {
    final question = session.questions[_index];
    final selected = _answer is List
        ? (_answer as List).map((value) => value.toString()).toSet()
        : {if (_answer != null) _answer.toString()};
    final correct = question.correctAnswer is List
        ? (question.correctAnswer as List)
              .map((value) => value.toString())
              .toSet()
        : {
            if (question.correctAnswer != null)
              question.correctAnswer.toString(),
          };
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'QUESTION ${_index + 1} OF ${session.questions.length}',
          style: const TextStyle(
            color: AppTheme.forest,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: (_index + 1) / session.questions.length),
        const SizedBox(height: 15),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (question.topic.isNotEmpty)
                Text(
                  question.topic,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                question.questionText,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (question.image != null) ...[
                const SizedBox(height: 12),
                _QuestionMedia(path: question.image!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final option in question.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              color: _isAnswered && session.showExplanations
                  ? correct.contains(option.key)
                        ? const Color(0xFFEAF4E7)
                        : selected.contains(option.key)
                        ? const Color(0xFFFCE9E7)
                        : null
                  : selected.contains(option.key)
                  ? const Color(0xFFE8F1EB)
                  : null,
              child: ListTile(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${option.key}. ${option.text}'),
                    if (option.image != null) ...[
                      const SizedBox(height: 8),
                      _QuestionMedia(path: option.image!),
                    ],
                  ],
                ),
                trailing: selected.contains(option.key)
                    ? const Icon(Icons.check_circle, color: AppTheme.forest)
                    : null,
                onTap: _isAnswered ? null : () => _selectOption(option.key),
              ),
            ),
          ),
        if (question.questionType == 'multiple_select' && !_isAnswered)
          FilledButton(
            onPressed: _checkMultipleSelect,
            child: const Text('Check answer'),
          ),
        if (_isAnswered && session.showExplanations)
          SurfaceCard(
            color: const Color(0xFFEAF4E7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCorrect ? 'Correct answer' : 'Review this answer',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(question.explanation),
              ],
            ),
          ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: _index == session.questions.length - 1
              ? 'Finish practice'
              : 'Next question',
          icon: Icons.arrow_forward_rounded,
          onPressed: _isAnswered ? _next : null,
        ),
      ],
    );
  }
}

class PracticeHistoryScreen extends StatefulWidget {
  const PracticeHistoryScreen({required this.service, super.key});

  final FirestoreCbtService service;

  @override
  State<PracticeHistoryScreen> createState() => _PracticeHistoryScreenState();
}

class _PracticeHistoryScreenState extends State<PracticeHistoryScreen> {
  late Future<List<Map<String, Object?>>> _history;

  @override
  void initState() {
    super.initState();
    _history = widget.service.loadPracticeHistory();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Practice history')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load local practice history: ${snapshot.error}',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data!;
        if (entries.isEmpty) {
          return const Center(
            child: Text('Completed practice sessions will appear here.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final percentage = (entry['percentage'] as num).toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SurfaceCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(
                    entry['subject_name']! as String,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${entry['correct_answers']}/${entry['total_questions']} correct · '
                    '${entry['time_spent']} seconds',
                  ),
                  trailing: Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: AppTheme.forest,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PracticeReviewScreen(
                        service: widget.service,
                        sessionId: entry['id']! as String,
                        subjectName: entry['subject_name']! as String,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class PracticeReviewScreen extends StatefulWidget {
  const PracticeReviewScreen({
    required this.service,
    required this.sessionId,
    required this.subjectName,
    super.key,
  });

  final FirestoreCbtService service;
  final String sessionId;
  final String subjectName;

  @override
  State<PracticeReviewScreen> createState() => _PracticeReviewScreenState();
}

class _PracticeReviewScreenState extends State<PracticeReviewScreen> {
  late Future<List<Map<String, Object?>>> _questions;

  @override
  void initState() {
    super.initState();
    _questions = widget.service.loadPracticeReview(widget.sessionId);
  }

  Set<String> _answers(Object? value) {
    if (value is List) return value.map((item) => item.toString()).toSet();
    if (value is String && value.startsWith('[')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toSet();
        }
      } on FormatException {
        return {value};
      }
    }
    return value == null ? <String>{} : {value.toString()};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.subjectName} review')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _questions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load the saved review: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final question = snapshot.data![index];
            final answer = question['practice_answer'] as Map?;
            final selected = _answers(answer?['selected_answer']);
            final correct = _answers(question['correct_answer']);
            final options = question['options'] as List? ?? const [];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${question['question_text']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    for (final rawOption in options)
                      Builder(
                        builder: (context) {
                          final option = Map<String, Object?>.from(
                            rawOption as Map,
                          );
                          final key =
                              option['option_key'] ?? option['id'] ?? '';
                          final isCorrect = correct.contains(key);
                          final isSelected = selected.contains(key);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? const Color(0xFFEAF4E7)
                                    : isSelected
                                    ? const Color(0xFFFCE9E7)
                                    : null,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '$key. ${option['option_text'] ?? option['text'] ?? ''}'
                                '${isCorrect ? ' · Correct' : ''}'
                                '${isSelected && !isCorrect ? ' · Your answer' : ''}',
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    Text(
                      (question['explanation'] as String?) ??
                          'No explanation is available.',
                      style: const TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class CbtAccessScreen extends StatefulWidget {
  const CbtAccessScreen({
    required this.controller,
    required this.service,
    this.selectedSubject,
    super.key,
  });
  final DemoAppController controller;
  final FirestoreCbtService service;
  final NaysSubject? selectedSubject;
  @override
  State<CbtAccessScreen> createState() => _CbtAccessScreenState();
}

class _CbtAccessScreenState extends State<CbtAccessScreen> {
  String? _error;
  String? _subjectId;
  List<NaysSubject> _subjects = const [];
  bool _isLoadingSubjects = true;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.selectedSubject?.subjectId;
    unawaited(_loadSubjects());
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await widget.service.watchRegisteredSubjects().first;
      if (!mounted) return;
      final sortedSubjects = [...subjects]
        ..sort(
          (a, b) => a.subjectName.toLowerCase().compareTo(
            b.subjectName.toLowerCase(),
          ),
        );
      widget.controller.setRegisteredSubjects({
        for (final subject in sortedSubjects)
          subject.subjectId: subject.subjectName,
      });
      final initialSubjectId = widget.selectedSubject?.subjectId;
      final selectedSubjectId =
          sortedSubjects.any((subject) => subject.subjectId == initialSubjectId)
          ? initialSubjectId
          : null;
      setState(() {
        _subjects = sortedSubjects;
        _subjectId =
            selectedSubjectId ??
            (sortedSubjects.isEmpty ? null : sortedSubjects.first.subjectId);
        _isLoadingSubjects = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingSubjects = false;
        _error = 'Could not load your registered subjects: $error';
      });
    }
  }

  Future<void> _startExam() async {
    final subjectId = _subjectId;
    if (subjectId == null ||
        !_subjects.any((subject) => subject.subjectId == subjectId)) {
      setState(() => _error = 'Choose one of your registered subjects.');
      return;
    }
    setState(() {
      _isStarting = true;
      _error = null;
    });
    try {
      if (await widget.service.loadActiveExam() != null) {
        if (mounted) {
          setState(
            () => _error =
                'Resume your saved examination before starting another.',
          );
        }
        return;
      }
      final session = await widget.service.startExam(subjectId: subjectId);
      if (!mounted) return;
      widget.controller.clearAnswers();
      String? persistenceWarning;
      if (widget.service.supportsOfflineRecovery) {
        try {
          await widget.service.saveExamProgress(
            session: session,
            answers: const {},
            currentQuestionIndex: 0,
          );
        } catch (error) {
          persistenceWarning = error.toString();
        }
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExamScreen(
            controller: widget.controller,
            service: widget.service,
            session: session,
            initialSaveError: persistenceWarning,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        final message =
            error is FirebaseFunctionsException && error.code == 'not-found'
            ? 'The exam service is not available yet. Please try again later or contact support.'
            : 'Could not start examination: $error';
        setState(() => _error = message);
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _subjects;
    return Scaffold(
      appBar: AppBar(title: const Text('Start examination')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const PageHeading(
            eyebrow: 'REGISTERED SUBJECTS',
            title: 'Ready to start?',
          ),
          const SizedBox(height: 20),
          if (_isLoadingSubjects)
            const Center(child: CircularProgressIndicator())
          else if (subjects.isEmpty)
            SurfaceCard(
              child: Column(
                children: [
                  const Text(
                    'Register for an active subject before starting an exam.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _loadSubjects,
                    child: const Text('Refresh subjects'),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _subjectId,
              decoration: const InputDecoration(
                labelText: 'Choose a registered subject',
              ),
              items: subjects
                  .map(
                    (subject) => DropdownMenuItem(
                      value: subject.subjectId,
                      child: Text(subject.subjectName),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _subjectId = value),
            ),
          const SizedBox(height: 15),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          PrimaryButton(
            label: 'Start examination',
            key: const ValueKey('cbt-access-continue'),
            icon: Icons.arrow_forward_rounded,
            onPressed: _isStarting || _isLoadingSubjects || subjects.isEmpty
                ? null
                : _startExam,
          ),
          const SizedBox(height: 14),
          const Text(
            'Questions, answers, and scores are stored on this device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class ExamScreen extends StatefulWidget {
  const ExamScreen({
    required this.controller,
    required this.service,
    required this.session,
    this.initialQuestionIndex = 0,
    this.initialSaveError,
    this.profile,
    super.key,
  });
  final DemoAppController controller;
  final FirestoreCbtService service;
  final CbtExamSession session;
  final int initialQuestionIndex;
  final String? initialSaveError;
  final AuthUserProfile? profile;
  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  late int _index = widget.initialQuestionIndex;
  bool _showPalette = false;
  bool _isSubmitting = false;
  bool _isConfirmingSubmission = false;
  bool _autoSubmitPending = false;
  String? _submitError;
  String? _progressError;
  int _seconds = -1;
  Timer? _timer;
  Future<void> _saveQueue = Future<void>.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progressError = widget.initialSaveError;
    _refreshRemainingTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshRemainingTime(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshRemainingTime();
  }

  void _refreshRemainingTime() {
    if (!mounted) return;
    final totalSeconds = widget.session.durationMinutes * 60;
    final elapsedSeconds = DateTime.now()
        .difference(widget.session.startedAt)
        .inSeconds;
    final remainingSeconds = totalSeconds - elapsedSeconds;
    final nextSeconds = remainingSeconds < 0
        ? 0
        : remainingSeconds > totalSeconds
        ? totalSeconds
        : remainingSeconds;
    if (nextSeconds == _seconds) return;
    setState(() => _seconds = nextSeconds);
    if (nextSeconds == 0) {
      _timer?.cancel();
      unawaited(_submit(confirm: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  String get _time =>
      '${(_seconds ~/ 3600).toString().padLeft(2, '0')}:${((_seconds ~/ 60) % 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  int get _answeredQuestionCount => widget.session.questions
      .where(
        (question) =>
            _hasAnswer(widget.controller.answers[question.questionId]),
      )
      .length;

  bool _hasAnswer(Object? answer) {
    if (answer == null) return false;
    if (answer is String) return answer.trim().isNotEmpty;
    if (answer is Iterable) return answer.isNotEmpty;
    if (answer is Map) return answer.isNotEmpty;
    return true;
  }

  Map<String, dynamic> _answersForSubmission() => {
    for (final question in widget.session.questions)
      if (_hasAnswer(widget.controller.answers[question.questionId]))
        question.questionId: widget.controller.answers[question.questionId],
  };

  Future<void> _persistProgress({bool rethrowOnFailure = false}) {
    if (!widget.session.isOffline && !widget.service.supportsOfflineRecovery) {
      return Future<void>.value();
    }
    final answers = Map<String, dynamic>.from(widget.controller.answers);
    final currentIndex = _index;
    final saveOperation = _saveQueue.then((_) async {
      try {
        if (widget.session.isOffline) {
          await widget.service.saveLocalExamProgress(
            session: widget.session,
            answers: answers,
            currentQuestionIndex: currentIndex,
          );
        } else {
          await widget.service.saveExamProgress(
            session: widget.session,
            answers: answers,
            currentQuestionIndex: currentIndex,
          );
        }
        if (mounted && _progressError != null) {
          setState(() => _progressError = null);
        }
      } catch (error) {
        if (mounted) setState(() => _progressError = error.toString());
        if (rethrowOnFailure) rethrow;
      }
    });
    _saveQueue = saveOperation.catchError((Object _) {});
    return saveOperation;
  }

  void _saveAnswer(String questionId, dynamic answer) {
    widget.controller.setAnswer(questionId, answer);
    unawaited(_persistProgress());
  }

  void _goToQuestion(int index) {
    setState(() => _index = index);
    unawaited(_persistProgress());
  }

  Future<bool> _confirmExit() async {
    if (_isSubmitting) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave this examination?'),
            content: const Text(
              'Leaving will end this attempt. Your answers will not be submitted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _submit({bool confirm = true}) async {
    if (_isSubmitting) return;
    if (_isConfirmingSubmission) {
      if (!confirm) _autoSubmitPending = true;
      return;
    }

    if (confirm) {
      _isConfirmingSubmission = true;
      final answeredCount = _answeredQuestionCount;
      final confirmation = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Submit examination?'),
          content: Text(
            'Are you sure you want to submit your examination? You have '
            'answered $answeredCount questions and left '
            '${widget.session.questions.length - answeredCount} unanswered. '
            'Once submitted, you cannot modify your answers.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit Exam'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      _isConfirmingSubmission = false;
      if (_autoSubmitPending) {
        _autoSubmitPending = false;
        if (confirmation != true) {
          await _submit(confirm: false);
          return;
        }
      }
      if (confirmation != true) return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      await _persistProgress(rethrowOnFailure: true);
      final submittedAnswers = _answersForSubmission();
      final result = widget.session.isOffline
          ? await widget.service.submitLocalExam(
              session: widget.session,
              durationSeconds: widget.session.durationMinutes * 60 - _seconds,
            )
          : await widget.service.submitExam(
              sessionId: widget.session.sessionId,
              answers: submittedAnswers,
              currentQuestionIndex: _index,
            );
      if (!mounted) return;
      _timer?.cancel();
      await widget.service.clearSavedExam(widget.session.sessionId);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            service: widget.service,
            session: widget.session,
            result: result,
            answers: submittedAnswers,
          ),
        ),
      );
    } catch (error) {
      if (mounted && error is CbtSubmissionQueuedException) {
        _timer?.cancel();
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OfflineSubmissionPendingScreen(
              session: widget.session,
              service: widget.service,
            ),
          ),
        );
      } else if (mounted) {
        setState(() => _submitError = error.toString());
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.session.questions[_index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = widget.profile?.photoUrl?.trim() ?? '';
    final subjectQuestionIndexes = <String, List<int>>{};
    final subjectNames = <String, String>{};
    for (var index = 0; index < widget.session.questions.length; index++) {
      final item = widget.session.questions[index];
      if (item.subjectId.isEmpty || item.subjectName.isEmpty) continue;
      subjectQuestionIndexes.putIfAbsent(item.subjectId, () => []).add(index);
      subjectNames[item.subjectId] = item.subjectName;
    }
    final activeQuestionIndexes =
        subjectQuestionIndexes[question.subjectId] ??
        List<int>.generate(widget.session.questions.length, (index) => index);
    final activeQuestionNumber = activeQuestionIndexes.indexOf(_index) + 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        final shouldExit = await _confirmExit();
        if (!didPop && shouldExit && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Exit practice',
            onPressed: () async {
              final shouldExit = await _confirmExit();
              if (shouldExit && context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.close_rounded),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.session.subjectName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                question.subjectName.isEmpty
                    ? 'EXAMINATION'
                    : question.subjectName.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  color: AppTheme.muted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF245A49)
                    : const Color(0xFFEAF2EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 17,
                    color: isDark ? Colors.white : AppTheme.forest,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _time,
                    style:
                        const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ).copyWith(
                          color: isDark ? Colors.white : AppTheme.forest,
                          fontSize: 14,
                        ),
                  ),
                ],
              ),
            ),
            if (widget.session.sessionId.startsWith('jamb_local_'))
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFFFF3D6),
                  child: ClipOval(
                    child: avatarUrl.isEmpty
                        ? Image.asset(
                            'assets/images/avarta.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            avatarUrl,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                                  'assets/images/avarta.png',
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                ),
                          ),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / widget.session.questions.length,
              minHeight: 4,
              color: AppTheme.forest,
              backgroundColor: const Color(0xFFE4EAE5),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'QUESTION $activeQuestionNumber OF ${activeQuestionIndexes.length}',
                          style: const TextStyle(
                            color: AppTheme.forest,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Text(
                        '$_answeredQuestionCount answered',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (_progressError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Offline recovery unavailable: $_progressError',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.questionText,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(height: 1.45),
                        ),
                        if (question.image != null) ...[
                          const SizedBox(height: 12),
                          _QuestionMedia(path: question.image!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 17),
                  if (question.questionType == 'fill_blank' ||
                      question.questionType == 'short_answer')
                    TextFormField(
                      key: ValueKey(question.questionId),
                      initialValue:
                          widget.controller.answers[question.questionId]
                              as String? ??
                          '',
                      maxLength: 5000,
                      decoration: const InputDecoration(
                        labelText: 'Your answer',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (answer) =>
                          _saveAnswer(question.questionId, answer),
                    ),
                  for (final option in question.options)
                    _AnswerTile(
                      letter: option.key,
                      label: option.text,
                      image: option.image,
                      selected: question.questionType == 'multiple_select'
                          ? (widget.controller.answers[question.questionId]
                                        as List<dynamic>? ??
                                    const [])
                                .contains(option.key)
                          : widget.controller.answers[question.questionId] ==
                                option.key,
                      onTap: () {
                        if (question.questionType == 'multiple_select') {
                          final selected = List<String>.from(
                            widget.controller.answers[question.questionId]
                                    as List<dynamic>? ??
                                const [],
                          );
                          if (selected.contains(option.key)) {
                            selected.remove(option.key);
                          } else {
                            selected.add(option.key);
                          }
                          _saveAnswer(question.questionId, selected);
                        } else {
                          _saveAnswer(question.questionId, option.key);
                        }
                      },
                    ),
                  if (_submitError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Submission failed: $_submitError',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _showPalette = !_showPalette),
                    icon: Icon(
                      _showPalette
                          ? Icons.expand_less_rounded
                          : Icons.grid_view_rounded,
                    ),
                    label: Text(
                      _showPalette
                          ? 'Hide question palette'
                          : 'Question palette',
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    child: _showPalette
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (subjectQuestionIndexes.isNotEmpty) ...[
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: subjectQuestionIndexes.entries
                                        .map(
                                          (entry) => ChoiceChip(
                                            selected:
                                                entry.key == question.subjectId,
                                            selectedColor: AppTheme.forest,
                                            checkmarkColor: Colors.white,
                                            label: Text(
                                              subjectNames[entry.key] ??
                                                  entry.key,
                                              style: TextStyle(
                                                color:
                                                    entry.key ==
                                                        question.subjectId
                                                    ? Colors.white
                                                    : Theme.of(
                                                        context,
                                                      ).colorScheme.onSurface,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            onSelected: (_) => _goToQuestion(
                                              entry.value.first,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Wrap(
                                  spacing: 9,
                                  runSpacing: 9,
                                  children: List.generate(
                                    activeQuestionIndexes.length,
                                    (subjectQuestionNumber) {
                                      final sessionIndex =
                                          activeQuestionIndexes[subjectQuestionNumber];
                                      return _QuestionDot(
                                        key: ValueKey(
                                          'jamb-palette-${question.subjectId}-${subjectQuestionNumber + 1}',
                                        ),
                                        number: subjectQuestionNumber + 1,
                                        current: sessionIndex == _index,
                                        answered: widget.controller.answers
                                            .containsKey(
                                              widget
                                                  .session
                                                  .questions[sessionIndex]
                                                  .questionId,
                                            ),
                                        onTap: () =>
                                            _goToQuestion(sessionIndex),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Answered questions are marked green.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: !_isSubmitting && _index > 0
                          ? () => _goToQuestion(_index - 1)
                          : null,
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            !_isSubmitting &&
                                _index < widget.session.questions.length - 1
                            ? () => _goToQuestion(_index + 1)
                            : null,
                        child: const Text('Next'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.deepGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isSubmitting ? 'Submitting…' : 'Submit'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionMedia extends StatelessWidget {
  const _QuestionMedia({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(path);
    final isNetworkImage =
        uri?.hasAuthority == true &&
        (uri?.scheme == 'https' || uri?.scheme == 'http');
    final imagePath = path.startsWith('assets/')
        ? path
        : 'assets/database/question_bank/$path';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: isNetworkImage
          ? Image.network(
              path,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const _QuestionImageError(),
            )
          : Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const _QuestionImageError(),
            ),
    );
  }
}

class _QuestionImageError extends StatelessWidget {
  const _QuestionImageError();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(8),
    child: Text(
      'Question image could not be loaded.',
      style: TextStyle(color: Colors.red, fontSize: 12),
    ),
  );
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.letter,
    required this.label,
    required this.selected,
    required this.onTap,
    this.image,
  });
  final String letter;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? image;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: selected
          ? const Color(0xFFE8F1EB)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? AppTheme.forest
                  : Theme.of(context).dividerColor.withValues(alpha: .2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.forest : const Color(0xFFF0F3F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? AppTheme.ink
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (image != null) ...[
                      const SizedBox(height: 8),
                      _QuestionMedia(path: image!),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppTheme.forest),
            ],
          ),
        ),
      ),
    ),
  );
}

class _QuestionDot extends StatelessWidget {
  const _QuestionDot({
    super.key,
    required this.number,
    required this.current,
    required this.answered,
    required this.onTap,
  });
  final int number;
  final bool current;
  final bool answered;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 43,
    height: 43,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: current
            ? AppTheme.gold
            : answered
            ? AppTheme.forest
            : Theme.of(context).colorScheme.surface,
        foregroundColor: current
            ? AppTheme.deepGreen
            : answered
            ? Colors.white
            : AppTheme.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: current
                ? AppTheme.gold
                : AppTheme.forest.withValues(alpha: .2),
          ),
        ),
      ),
      child: Text(
        '$number',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class OfflineSubmissionPendingScreen extends StatefulWidget {
  const OfflineSubmissionPendingScreen({
    required this.session,
    required this.service,
    super.key,
  });

  final CbtExamSession session;
  final FirestoreCbtService service;

  @override
  State<OfflineSubmissionPendingScreen> createState() =>
      _OfflineSubmissionPendingScreenState();
}

class _OfflineSubmissionPendingScreenState
    extends State<OfflineSubmissionPendingScreen> {
  bool _isRetrying = false;
  String? _error;

  Future<void> _retry() async {
    setState(() {
      _isRetrying = true;
      _error = null;
    });
    try {
      await widget.service.syncPendingSubmissions();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Submission pending'),
      automaticallyImplyLeading: false,
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_upload_outlined,
              size: 52,
              color: AppTheme.forest,
            ),
            const SizedBox(height: 15),
            Text(
              '${widget.session.subjectName} is saved on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your score will be graded by the server after the submission syncs. '
              'Because the device was offline, its submission time will remain '
              'pending verification and will not count toward leaderboards. '
              'Reconnect within 24 hours of the exam deadline.',
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isRetrying ? null : _retry,
              icon: const Icon(Icons.sync_rounded),
              label: Text(_isRetrying ? 'Retrying…' : 'Retry now'),
            ),
            TextButton(
              onPressed: _isRetrying
                  ? null
                  : () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
              child: const Text('Return to CBT centre'),
            ),
          ],
        ),
      ),
    ),
  );
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    required this.service,
    required this.session,
    required this.result,
    required this.answers,
    super.key,
  });
  final FirestoreCbtService service;
  final CbtExamSession session;
  final Map<String, dynamic> result;
  final Map<String, dynamic> answers;

  @override
  Widget build(BuildContext context) {
    final pendingVerification = result['status'] == 'pending_verification';
    final percent = (result['percentage'] as num).round();
    final correct = result['correctAnswers'] as int;
    final incorrect = result['incorrectAnswers'] as int;
    final unanswered = result['unanswered'] as int;
    final total = result['questionCount'] as int;
    final score = result['score'] as num;
    final totalMarks = result['totalMarks'] as num;
    final secondsUsed = result['timeSpent'] as int;
    final topicPerformance = result['topicPerformance'];
    final time =
        '${(secondsUsed ~/ 60).toString().padLeft(2, '0')}:${(secondsUsed % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Examination result'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              color: AppTheme.deepGreen,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: AppTheme.gold,
                  size: 36,
                ),
                const SizedBox(height: 11),
                Text(
                  session.subjectName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pendingVerification ? 'Pending verification' : '$percent%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: pendingVerification ? 22 : 48,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  pendingVerification
                      ? 'The server graded this attempt; timing is unverified and it is excluded from leaderboards.'
                      : '$score of $totalMarks marks · ${result['status']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!pendingVerification) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    value: '$correct',
                    label: 'Correct',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    value: '$incorrect',
                    label: 'Incorrect',
                    icon: Icons.cancel_outlined,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  value: '${total - unanswered}',
                  label: 'Answered',
                  icon: Icons.checklist_rounded,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  value: '$unanswered',
                  label: 'Unanswered',
                  icon: Icons.radio_button_unchecked,
                ),
              ),
            ],
          ),
          if (topicPerformance is Map && topicPerformance.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionLabel('Topic performance'),
            const SizedBox(height: 8),
            for (final entry in topicPerformance.entries)
              SurfaceCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key.toString()),
                  subtitle: Text(
                    '${(entry.value as Map)['correctAnswers']} of '
                    '${(entry.value as Map)['totalQuestions']} correct',
                  ),
                  trailing: Text(
                    '${((entry.value as Map)['percentage'] as num).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 13),
          SurfaceCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined, color: AppTheme.forest),
              title: const Text('Time used'),
              trailing: Text(
                time,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Review answers',
            icon: Icons.fact_check_outlined,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReviewScreen(
                  session: session,
                  answers: answers,
                  result: result,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryScreen(service: service),
              ),
            ),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Exam history'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text('Return to dashboard'),
          ),
        ],
      ),
    );
  }
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    required this.session,
    required this.answers,
    this.result,
    super.key,
  });
  final CbtExamSession session;
  final Map<String, dynamic> answers;
  final Map<String, dynamic>? result;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _index = 0;

  Map<String, dynamic>? _resultDetails(String questionId) {
    final review = widget.result?['questionReview'];
    if (review is! List) return null;
    for (final item in review) {
      if (item is Map && item['questionId'] == questionId) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.session.questions[_index];
    final answer = widget.answers[question.questionId];
    final resultDetails = _resultDetails(question.questionId);
    final correctAnswer =
        question.correctAnswer ?? resultDetails?['correctAnswer'];
    final explanation = question.explanation.isNotEmpty
        ? question.explanation
        : resultDetails?['explanation'] as String? ?? '';
    final selectedAnswers = answer is List
        ? answer.map((value) => value.toString()).toSet()
        : {if (answer != null) answer.toString()};
    final correctAnswers = correctAnswer is List
        ? correctAnswer.map((value) => value.toString()).toSet()
        : {if (correctAnswer != null) correctAnswer.toString()};
    return Scaffold(
      appBar: AppBar(title: const Text('Answer review')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'QUESTION ${_index + 1} OF ${widget.session.questions.length}',
            style: const TextStyle(
              color: AppTheme.forest,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.questionText,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (question.image != null) ...[
                  const SizedBox(height: 12),
                  _QuestionMedia(path: question.image!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (question.questionType == 'fill_blank' ||
              question.questionType == 'short_answer')
            SurfaceCard(
              color: const Color(0xFFE8F1EB),
              child: Text(
                answer?.toString().isNotEmpty == true
                    ? answer.toString()
                    : 'No answer was submitted for this question.',
                style: const TextStyle(color: AppTheme.ink),
              ),
            ),
          for (final option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfaceCard(
                padding: const EdgeInsets.all(13),
                color: selectedAnswers.contains(option.key)
                    ? correctAnswers.contains(option.key)
                          ? const Color(0xFFEAF4E7)
                          : const Color(0xFFFCE9E7)
                    : correctAnswer != null &&
                          correctAnswers.contains(option.key)
                    ? const Color(0xFFEAF4E7)
                    : null,
                child: Row(
                  children: [
                    Text(
                      option.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.forest,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.text,
                            style: const TextStyle(color: AppTheme.ink),
                          ),
                          if (option.image != null) ...[
                            const SizedBox(height: 8),
                            _QuestionMedia(path: option.image!),
                          ],
                        ],
                      ),
                    ),
                    if (selectedAnswers.contains(option.key))
                      Text(
                        'Your answer',
                        style: TextStyle(
                          color: correctAnswers.contains(option.key)
                              ? AppTheme.forest
                              : Color(0xFF8F211B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (widget.session.showExplanations &&
                        correctAnswers.contains(option.key))
                      const Text(
                        'Correct answer',
                        style: TextStyle(
                          color: AppTheme.forest,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (answer == null)
            const Text(
              'No answer was submitted for this question.',
              style: TextStyle(color: AppTheme.muted),
            ),
          if (widget.session.showExplanations && correctAnswer != null) ...[
            const SizedBox(height: 12),
            SurfaceCard(
              color: const Color(0xFFEAF4E7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explanation',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (question.options.isEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Correct answer: $correctAnswer',
                      style: const TextStyle(color: AppTheme.ink),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    explanation,
                    style: const TextStyle(color: AppTheme.ink, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              OutlinedButton(
                onPressed: _index > 0 ? () => setState(() => _index--) : null,
                child: const Text('Previous'),
              ),
              const Spacer(),
              Text('${_index + 1}/${widget.session.questions.length}'),
              const Spacer(),
              FilledButton(
                onPressed: _index < widget.session.questions.length - 1
                    ? () => setState(() => _index++)
                    : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
