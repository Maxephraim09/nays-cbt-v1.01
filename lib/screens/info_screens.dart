import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../services/firestore_models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/nays_widgets.dart';
import 'leaderboard_screen.dart';
import 'terms_of_service_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({this.service, super.key});

  final FirestoreCbtService? service;

  @override
  Widget build(BuildContext context) =>
      _FirestoreExamHistoryScreen(service: service ?? FirestoreCbtService());
}

class _FirestoreExamHistoryScreen extends StatefulWidget {
  const _FirestoreExamHistoryScreen({required this.service});

  final FirestoreCbtService service;

  @override
  State<_FirestoreExamHistoryScreen> createState() =>
      _FirestoreExamHistoryScreenState();
}

class _FirestoreExamHistoryScreenState
    extends State<_FirestoreExamHistoryScreen> {
  final List<NaysResult> _olderResults = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _loadMoreError;

  Future<void> _loadMore(List<NaysResult> visibleResults) async {
    if (_isLoadingMore || !_hasMore || visibleResults.isEmpty) return;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });
    try {
      final page = await widget.service.fetchOlderResults(
        after: visibleResults.last,
      );
      if (!mounted) return;
      final existingIds = _olderResults
          .map((result) => result.resultId)
          .toSet();
      setState(() {
        _olderResults.addAll(
          page.where((result) => existingIds.add(result.resultId)),
        );
        _hasMore = page.length == 50;
      });
    } catch (error) {
      if (mounted) setState(() => _loadMoreError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Exam history'),
      actions: [
        IconButton(
          tooltip: 'Leaderboard',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LeaderboardScreen(service: widget.service),
            ),
          ),
          icon: const Icon(Icons.leaderboard_outlined),
        ),
      ],
    ),
    body: StreamBuilder<List<NaysResult>>(
      stream: widget.service.watchResults(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load exam history: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final latestResults = snapshot.data!;
        final seenIds = <String>{};
        final results = [
          ...latestResults,
          ..._olderResults,
        ].where((result) => seenIds.add(result.resultId)).toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const PageHeading(
              eyebrow: 'YOUR RESULTS',
              title: 'Exam history',
              subtitle: 'Completed examination attempts saved on this device.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeaderboardScreen(service: widget.service),
                ),
              ),
              icon: const Icon(Icons.leaderboard_outlined),
              label: const Text('View leaderboard'),
            ),
            const SizedBox(height: 12),
            if (results.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Completed examinations will appear here.'),
                ),
              ),
            for (final result in results)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEAF2EC),
                      child: Icon(
                        Icons.assignment_turned_in_outlined,
                        color: AppTheme.forest,
                      ),
                    ),
                    title: Text(
                      result.subjectName.isEmpty
                          ? result.subjectId
                          : result.subjectName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      result.status == 'pending_verification'
                          ? '${result.submittedAt.toLocal()} · Pending verification'
                          : '${result.submittedAt.toLocal()} · ${result.correctAnswers}/${result.questionCount} correct',
                    ),
                    trailing: Text(
                      result.status == 'pending_verification'
                          ? 'Pending'
                          : '${result.percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: AppTheme.forest,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (context) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.subjectName.isEmpty
                                    ? result.subjectId
                                    : result.subjectName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              if (result.status == 'pending_verification')
                                const Text(
                                  'The server graded this attempt, but its offline timing has not been verified. It is excluded from leaderboards.',
                                )
                              else ...[
                                Text(
                                  'Score: ${result.score}/${result.totalMarks}',
                                ),
                                Text(
                                  'Percentage: ${result.percentage.toStringAsFixed(1)}%',
                                ),
                                Text('Questions: ${result.questionCount}'),
                                Text('Correct: ${result.correctAnswers}'),
                                Text('Incorrect: ${result.incorrectAnswers}'),
                                Text('Unanswered: ${result.unanswered}'),
                                Text('Time taken: ${result.timeSpent} seconds'),
                              ],
                              Text('Status: ${result.status}'),
                              Text(
                                'Completed: ${result.submittedAt.toLocal()}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (latestResults.length == 50 && _hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    if (_loadMoreError != null)
                      Text(
                        'Could not load older results: $_loadMoreError',
                        textAlign: TextAlign.center,
                      ),
                    OutlinedButton(
                      onPressed: _isLoadingMore
                          ? null
                          : () => _loadMore(results),
                      child: _isLoadingMore
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Load older results'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({this.service, super.key});

  final FirestoreCbtService? service;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

const _welcomeAnnouncement = NaysAnnouncement(
  announcementId: 'nays-welcome',
  title: 'Welcome to NAYS CBT',
  message:
      'Welcome! Explore the local question bank, practise for your examinations, '
      'and check this page for updates published by NAYS.',
  image: '',
  isActive: true,
);

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final FirestoreCbtService _service =
      widget.service ?? FirestoreCbtService();
  late Future<List<NaysAnnouncement>> _announcements;

  @override
  void initState() {
    super.initState();
    _announcements = _service.fetchAnnouncements();
  }

  void _reload() {
    setState(() => _announcements = _service.fetchAnnouncements());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Announcements')),
    body: FutureBuilder<List<NaysAnnouncement>>(
      future: _announcements,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load announcements: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final announcements = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PageHeading(
              eyebrow: 'NAYS UPDATES',
              title: 'Announcements',
              subtitle: 'Welcome message and updates published by NAYS.',
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _AnnouncementCard(announcement: _welcomeAnnouncement),
            ),
            if (announcements.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No other announcements yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final announcement in announcements.where(
              (announcement) =>
                  announcement.announcementId !=
                  _welcomeAnnouncement.announcementId,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AnnouncementCard(announcement: announcement),
              ),
          ],
        );
      },
    ),
  );
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});

  final NaysAnnouncement announcement;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFEAF2EC),
              child: Icon(
                Icons.campaign_outlined,
                color: AppTheme.forest,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                announcement.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (announcement.createdAt != null) ...[
          const SizedBox(height: 8),
          Text(
            announcement.createdAt!.toLocal().toString(),
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        Text(announcement.message),
        if (announcement.image.isNotEmpty) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              announcement.image,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 40,
                child: Center(child: Text('Announcement image unavailable.')),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & support')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeading(
          eyebrow: 'NAYS CBT SUPPORT',
          title: 'How can we help?',
          subtitle: 'Contact the support team or browse common questions.',
        ),
        const SizedBox(height: 18),
        const SectionLabel('Contact support'),
        const SizedBox(height: 9),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SupportContact(
                icon: Icons.email_outlined,
                title: 'Email support',
                value: 'mgtechs09@gmail.com',
                uri: Uri(scheme: 'mailto', path: 'mgtechs09@gmail.com'),
              ),
              const Divider(height: 1, indent: 58),
              _SupportContact(
                icon: Icons.call_outlined,
                title: 'Call support',
                value: '08161595906',
                uri: Uri(scheme: 'tel', path: '08161595906'),
              ),
              const Divider(height: 1, indent: 58),
              _SupportContact(
                leading: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: AppTheme.forest,
                ),
                title: 'WhatsApp support',
                value: '+2348161595906',
                uri: Uri.https('wa.me', '/2348161595906'),
              ),
              const Divider(height: 1, indent: 58),
              ListTile(
                key: const ValueKey('report-issue'),
                leading: const Icon(
                  Icons.flag_outlined,
                  color: AppTheme.forest,
                ),
                title: const Text('Report an issue'),
                subtitle: const Text('Describe a problem with the app'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showIssueReport(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        const SectionLabel('Frequently asked questions'),
        const SizedBox(height: 9),
        const _Faq(
          title: 'How do I register a subject?',
          answer:
              'Open CBT, choose Register subjects, then select up to ten subjects.',
        ),
        const _Faq(
          title: 'Are these exam results official?',
          answer:
              'No. Questions, scores and history in this app are local demonstration data.',
        ),
        const _Faq(
          title: 'Does the app need internet?',
          answer:
              'The current prototype uses bundled assets and local sample content. Contact actions open your device apps.',
        ),
      ],
    ),
  );

  Future<void> _showIssueReport(BuildContext context) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => const _IssueReportDialog(),
    );
    if (submitted == true && context.mounted) {
      showDemoMessage(
        context,
        'Report recorded locally',
        'This design prototype does not send issue reports to a server.',
      );
    }
  }
}

class _IssueReportDialog extends StatefulWidget {
  const _IssueReportDialog();

  @override
  State<_IssueReportDialog> createState() => _IssueReportDialogState();
}

class _IssueReportDialogState extends State<_IssueReportDialog> {
  final _description = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Report an issue'),
    content: TextField(
      controller: _description,
      minLines: 3,
      maxLines: 5,
      onChanged: (_) => setState(() => _error = null),
      decoration: InputDecoration(
        labelText: 'What happened?',
        alignLabelWithHint: true,
        errorText: _error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_description.text.trim().isEmpty) {
            setState(() => _error = 'Describe the issue before submitting.');
            return;
          }
          Navigator.pop(context, true);
        },
        child: const Text('Submit report'),
      ),
    ],
  );
}

class _SupportContact extends StatelessWidget {
  const _SupportContact({
    this.icon,
    this.leading,
    required this.title,
    required this.value,
    required this.uri,
  });
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String value;
  final Uri uri;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: leading ?? Icon(icon!, color: AppTheme.brand(context)),
    title: Text(title),
    subtitle: Text(value),
    trailing: const Icon(Icons.open_in_new_rounded, size: 17),
    onTap: () async {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No compatible app is available.')),
        );
      }
    },
  );
}

class _Faq extends StatelessWidget {
  const _Faq({required this.title, required this.answer});
  final String title;
  final String answer;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: SurfaceCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            answer,
            style: const TextStyle(color: AppTheme.muted, height: 1.45),
          ),
        ],
      ),
    ),
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  static const _about = r'''# ABOUT NAYS CBT
**National Association of Yungur Students (NAYS)**

**BƏNA NDO FINI**

Welcome to the **NAYS CBT Application**, the official Computer-Based Testing platform designed to promote digital learning, academic excellence, knowledge assessment and educational development among Yungur students.

The NAYS CBT App provides students with a modern, convenient and accessible platform for participating in computer-based examinations directly from their mobile devices.

Our goal is to leverage technology to improve the way students learn, prepare for examinations and assess their academic knowledge while promoting unity, educational advancement and the development of the Yungur community.

## OUR FEATURES
- **Online Examinations:** Participate in CBT examinations using your mobile device.
- **Question Bank:** Access organized examination questions across different subjects and categories.
- **Instant Results:** View your examination scores and performance after submission, where results are released.
- **Examination History:** Keep track of previous examination attempts and results.
- **Academic Calendar:** Stay informed about examination schedules and important academic activities.
- **Notifications:** Receive important announcements and examination updates.
- **Student Support:** Access assistance and support whenever necessary.

## OUR MISSION
To empower Yungur students through technology-driven educational solutions, encourage academic excellence and create opportunities for continuous learning, assessment and intellectual development.

## OUR VISION
To become a reliable digital educational platform that connects, educates and empowers Yungur students while contributing to a brighter future for the Yungur community.

## DEVELOPED BY
**MGTechs Smart Innovations Limited**

**Lead Developer:** Maxwell Ephraim H.

MGTechs Smart Innovations Limited is a technology and digital innovation company specializing in software development, mobile applications, web solutions, UI/UX design, artificial intelligence and digital transformation.

We are proud to contribute to educational development through innovative technology solutions.

**Tagline:** EXPERIENCE IT.

---

**© 2026 National Association of Yungur Students (NAYS).**

Powered by MGTechs Smart Innovations Limited.

*Technology for Education. Innovation for Progress. Excellence for the Future.*
''';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About NAYS CBT')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const BrandMark(size: 92),
          ),
        ),
        const SizedBox(height: 14),
        MarkdownBody(
          data: _about,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.brand(context),
            ),
            h2: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppTheme.brand(context)),
            p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SupportContact(
                icon: Icons.email_outlined,
                title: 'Email developer',
                value: 'mgtechs09@gmail.com',
                uri: Uri(scheme: 'mailto', path: 'mgtechs09@gmail.com'),
              ),
              const Divider(height: 1, indent: 58),
              _SupportContact(
                icon: Icons.call_outlined,
                title: 'Call developer',
                value: '08161595906',
                uri: Uri(scheme: 'tel', path: '08161595906'),
              ),
              const Divider(height: 1, indent: 58),
              _SupportContact(
                icon: Icons.language_rounded,
                title: 'Developer website',
                value: 'www.mgtechs.com.ng',
                uri: Uri.https('www.mgtechs.com.ng'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'Powered by MGTechs Smart Innovations Limited · EXPERIENCE IT.',
            style: TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _policy = r'''# Privacy

NAYS CBT is designed to work offline. Exam questions, answers, practice progress,
and examination results are stored on your device.

## Account information

Account details and preferences are kept on this device for local app use.
Firebase Authentication is used for online account sign-in and optional email
verification. You can use the app offline with your locally available account.

## Online features

When you are connected, the app may use Firebase Authentication and retrieve
leaderboard or NAYS-published announcement data. Exam question banks and local
exam results are not uploaded to Firestore.

## Your choices

You can use the app offline, and choose to verify your email later from your
profile. Removing the app or clearing its storage may delete locally saved
accounts, preferences, and exam data.

For privacy questions, contact **mgtechs09@gmail.com**.
''';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        MarkdownBody(
          data: _policy,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.brand(context),
            ),
            h2: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppTheme.brand(context)),
            p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
        ),
      ],
    ),
  );
}

class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({
    required this.onOpen,
    required this.service,
    required this.onOpenExamsSettings,
    super.key,
  });

  final ValueChanged<Widget> onOpen;
  final FirestoreCbtService service;
  final VoidCallback onOpenExamsSettings;

  static const _links = [
    (
      'Exam history',
      'Review completed practice sessions',
      Icons.history_rounded,
      HistoryScreen(),
    ),
    (
      'Notifications',
      'Announcements and examination updates',
      Icons.notifications_outlined,
      NotificationsScreen(),
    ),
    (
      'App settings',
      'Theme, notification preference and account',
      Icons.tune_rounded,
      SettingsScreen(),
    ),
    (
      'Help & support',
      'Contact support and browse FAQs',
      Icons.help_outline_rounded,
      SupportScreen(),
    ),
    (
      'About NAYS',
      'Organization, mission and developer',
      Icons.info_outline_rounded,
      AboutScreen(),
    ),
    (
      'Terms of service',
      'Read the terms for using NAYS CBT',
      Icons.description_outlined,
      TermsOfServiceScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('settings-hub'),
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
    children: [
      const PageHeading(
        eyebrow: 'PREFERENCES & INFORMATION',
        title: 'Settings',
        subtitle: 'Manage your app and find the information you need.',
      ),
      const SizedBox(height: 17),
      SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var index = 0; index < _links.length; index++) ...[
              ListTile(
                key: ValueKey('settings-link-$index'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF183D35)
                      : const Color(0xFFD8F6F0),
                  child: Icon(_links[index].$3, color: AppTheme.brand(context)),
                ),
                title: Text(
                  _links[index].$1,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(_links[index].$2),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onOpen(switch (index) {
                  0 => HistoryScreen(service: service),
                  2 => const SettingsScreen(),
                  _ => _links[index].$4,
                }),
              ),
              if (index < _links.length - 1)
                const Divider(height: 1, indent: 74),
            ],
            const Divider(height: 1, indent: 74),
            ListTile(
              key: const ValueKey('settings-exams'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 4,
              ),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF183D35)
                    : const Color(0xFFD8F6F0),
                child: Icon(
                  Icons.fact_check_rounded,
                  color: AppTheme.brand(context),
                ),
              ),
              title: const Text(
                'Exams settings',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Manage examination preferences and subjects',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onOpenExamsSettings,
            ),
          ],
        ),
      ),
    ],
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('App settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PageHeading(eyebrow: 'PREFERENCES', title: 'Settings'),
          const SizedBox(height: 14),
          SurfaceCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark theme'),
                  value: state.themeMode == ThemeMode.dark,
                  onChanged: state.setDarkTheme,
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  value: state.notificationsEnabled,
                  onChanged: state.setNotifications,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            tileColor: Theme.of(context).colorScheme.surface,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          ListTile(
            tileColor: Theme.of(context).colorScheme.surface,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of use'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
            ),
          ),
          const SizedBox(height: 8),
          const SurfaceCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline_rounded),
              title: Text('App Version'),
              subtitle: Text('v1.0.1'),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Return to the welcome screen? Your cloud data will remain saved to your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) {
      await AppScope.auth(context).signOut();
    }
  }
}
