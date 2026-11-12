import 'dart:async';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../auth_service.dart';
import '../auth_user_profile.dart';
import '../data/demo_data.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/nays_widgets.dart';
import 'cbt_screens.dart';
import 'home_dashboard.dart';
import 'info_screens.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    required this.controller,
    this.profile,
    this.authService,
    this.firestoreService,
    super.key,
  });
  final DemoAppController controller;
  final AuthUserProfile? profile;
  final FirebaseAuthService? authService;
  final FirestoreCbtService? firestoreService;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  late final FirestoreCbtService _firestoreService =
      widget.firestoreService ??
      FirestoreCbtService(localUserId: widget.profile?.uid);
  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _openExamsSettings() => _open(
    ExamsSettingsScreen(
      controller: widget.controller,
      service: _firestoreService,
      onOpen: _open,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: IndexedStack(
        index: _tab,
        children: [
          HomeDashboardTab(
            controller: widget.controller,
            profile: widget.profile,
            service: _firestoreService,
            onTab: (value) => setState(() => _tab = value),
            onOpen: _open,
          ),
          CbtHubScreen(
            controller: widget.controller,
            onOpen: _open,
            profile: widget.profile,
            service: _firestoreService,
            isActive: _tab == 1,
          ),
          SettingsHubScreen(
            onOpen: _open,
            service: _firestoreService,
            onOpenExamsSettings: _openExamsSettings,
          ),
          ProfileTab(
            onOpen: _open,
            profile: widget.profile,
            authService: widget.authService,
            service: _firestoreService,
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      key: const ValueKey('main-navigation'),
      selectedIndex: _tab,
      onDestinationSelected: (value) => setState(() => _tab = value),
      height: 70,
      destinations: const [
        NavigationDestination(
          key: ValueKey('nav-home'),
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          key: ValueKey('nav-services'),
          icon: Icon(Icons.grid_view_rounded),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: 'Services',
        ),
        NavigationDestination(
          key: ValueKey('nav-settings'),
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
        NavigationDestination(
          key: ValueKey('nav-profile'),
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    ),
  );
}

class HomeTab extends StatelessWidget {
  const HomeTab({
    required this.controller,
    required this.onTab,
    required this.onOpen,
    this.service,
    super.key,
  });
  final DemoAppController controller;
  final ValueChanged<int> onTab;
  final ValueChanged<Widget> onOpen;
  final FirestoreCbtService? service;
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            Row(
              children: [
                const BrandMark(size: 38),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'NAYS CBT',
                    style: TextStyle(
                      color: AppTheme.forest,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => onOpen(const NotificationsScreen()),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                IconButton(
                  tooltip: 'Profile',
                  onPressed: () => onTab(3),
                  icon: const CircleAvatar(
                    radius: 15,
                    backgroundColor: Color(0xFFFFF3D6),
                    backgroundImage: AssetImage('assets/images/avarta.png'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'GOOD MORNING, AMARA',
              style: TextStyle(
                color: AppTheme.forest,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Ready for your\nnext practice?',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 19),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.forest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR NEXT STEP',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Small practice sessions build big confidence.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose any subject and practise instantly with the question bank saved on this device.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 15),
                  FilledButton.icon(
                    onPressed: () => onOpen(
                      PracticeSubjectsScreen(
                        service: service ?? FirestoreCbtService(),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.deepGreen,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start practice'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => onOpen(
                      CbtAccessScreen(
                        controller: controller,
                        service: service ?? FirestoreCbtService(),
                      ),
                    ),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('Start exam simulation'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Your overview'),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(
                  child: MetricTile(
                    value: '76%',
                    label: 'Average score',
                    icon: Icons.trending_up_rounded,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    value: '12',
                    label: 'Practice exams',
                    icon: Icons.assignment_turned_in_outlined,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    value: '4',
                    label: 'Subjects',
                    icon: Icons.menu_book_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SectionLabel(
              'Registered subjects',
              action: 'Manage',
              onAction: () => onTab(1),
            ),
            const SizedBox(height: 10),
            SurfaceCard(
              child: Column(
                children: controller.subjects
                    .map(
                      (subject) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEAF2EC),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: AppTheme.forest,
                            size: 19,
                          ),
                        ),
                        title: Text(
                          subject,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 19,
                        ),
                        onTap: () => onTab(1),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Your readiness'),
            const SizedBox(height: 10),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(child: Text('Weekly practice goal')),
                      Text(
                        '3 of 5',
                        style: TextStyle(
                          color: AppTheme.forest,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  const LinearProgressIndicator(
                    value: .6,
                    minHeight: 8,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    color: AppTheme.forest,
                    backgroundColor: Color(0xFFE7ECE8),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Two more sessions to reach your goal.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SectionLabel(
              'Recent activity',
              action: 'View history',
              onAction: () => onOpen(const HistoryScreen()),
            ),
            const SizedBox(height: 10),
            const SurfaceCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFFFF3D6),
                  child: Icon(Icons.check_rounded, color: AppTheme.deepGreen),
                ),
                title: Text(
                  'Biology practice',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('28 Oct 2026 · Sample result'),
                trailing: Text(
                  '76%',
                  style: TextStyle(
                    color: AppTheme.forest,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'All scores and activity shown are sample data.',
                style: TextStyle(color: AppTheme.muted, fontSize: 11),
              ),
            ),
          ]),
        ),
      ),
    ],
  );
}

class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key});
  static const _scores = [
    ('Biology', .76),
    ('English Language', .68),
    ('Mathematics', .82),
    ('Chemistry', .61),
  ];
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
    children: [
      const PageHeading(
        eyebrow: 'YOUR LEARNING',
        title: 'Progress',
        subtitle: 'A snapshot of your examination activity.',
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.deepGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OVERALL PERFORMANCE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '74%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Sample average across subjects',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.insights_rounded, color: AppTheme.gold, size: 46),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const Row(
        children: [
          Expanded(
            child: MetricTile(
              value: '12',
              label: 'Attempted',
              icon: Icons.edit_note_rounded,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: MetricTile(
              value: '9',
              label: 'Completed',
              icon: Icons.task_alt_rounded,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const SectionLabel('By subject'),
      const SizedBox(height: 10),
      ..._scores.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SurfaceCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${(item.$2 * 100).round()}%',
                      style: const TextStyle(
                        color: AppTheme.forest,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: item.$2,
                  minHeight: 7,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  color: AppTheme.forest,
                  backgroundColor: const Color(0xFFE7ECE8),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      const SectionLabel('Recent exam history'),
      const SizedBox(height: 10),
      for (final entry in sampleHistory)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: SurfaceCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                entry.$1,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${entry.$2} · ${entry.$4}'),
              trailing: Text(
                entry.$3,
                style: const TextStyle(
                  color: AppTheme.forest,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      const Center(
        child: Text(
          'Demonstration data only',
          style: TextStyle(color: AppTheme.muted, fontSize: 11),
        ),
      ),
    ],
  );
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({
    required this.onOpen,
    this.profile,
    this.authService,
    this.service,
    super.key,
  });
  final ValueChanged<Widget> onOpen;
  final AuthUserProfile? profile;
  final FirebaseAuthService? authService;
  final FirestoreCbtService? service;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final FirebaseAuthService _authService =
      widget.authService ?? FirebaseAuthService();
  late final FirestoreCbtService _service =
      widget.service ?? FirestoreCbtService();
  late String _displayName = widget.profile?.displayName ?? '';
  late String _phoneNumber = widget.profile?.phoneNumber ?? '';
  late bool _emailVerified = widget.profile?.emailVerified ?? false;
  String? _profileLoadError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _service.loadAuthenticatedProfile();
      if (!mounted) return;
      setState(() {
        _displayName = (data['fullName'] as String?) ?? _displayName;
        _phoneNumber = (data['phone'] as String?) ?? _phoneNumber;
        _profileLoadError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _profileLoadError = error.toString());
    }
  }

  Future<void> _editProfile() async {
    var name = _displayName;
    var phone = _phoneNumber;
    final formKey = GlobalKey<FormState>();
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your name.'
                    : null,
                onSaved: (value) => name = value!.trim(),
              ),
              TextFormField(
                initialValue: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
                onSaved: (value) => phone = value?.trim() ?? '',
              ),
              const SizedBox(height: 8),
              const Text(
                'Your email is managed by your sign-in provider and cannot be changed here.',
                style: TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(context, (name, phone));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (values == null) return;
    try {
      await _service.updateUserProfile(
        displayName: values.$1,
        phoneNumber: values.$2,
      );
      if (!mounted) return;
      setState(() {
        _displayName = values.$1;
        _phoneNumber = values.$2;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _displayName = values.$1;
        _phoneNumber = values.$2;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save profile changes on this device: $error',
          ),
        ),
      );
    }
  }

  Future<void> _verifyEmail() async {
    String? password;
    if (widget.profile?.isLocalAccount == true) {
      final localAccount = await _authService.currentLocalAccount();
      if (!mounted) return;
      final firebaseUser = _authService.currentUser;
      if (localAccount?.pendingPassword == null &&
          firebaseUser?.email?.toLowerCase() !=
              widget.profile?.email.toLowerCase()) {
        final controller = TextEditingController();
        password = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verify email'),
            content: TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Account password'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        controller.dispose();
        if (password == null || !mounted) return;
      }
    }

    try {
      if (widget.profile?.isLocalAccount == true) {
        await _authService.verifyLocalAccount(password: password);
      } else {
        await _authService.refreshCurrentUser();
        if (_authService.currentUser?.emailVerified != true) {
          await _authService.resendVerification();
        }
      }
      if (!mounted) return;
      final bool verified;
      if (widget.profile?.isLocalAccount == true) {
        verified =
            (await _authService.currentLocalAccount())?.emailVerified ?? false;
        if (!mounted) return;
      } else {
        verified = _authService.currentUser?.emailVerified ?? false;
      }
      setState(() => _emailVerified = verified);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? 'Your email is verified.'
                : 'Verification email sent. Open the link, then return here '
                      'and tap Verify email again.',
          ),
        ),
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email verification could not start: $error')),
      );
    }
  }

  @override
  void didUpdateWidget(covariant ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _displayName = widget.profile?.displayName ?? _displayName;
      _phoneNumber = widget.profile?.phoneNumber ?? _phoneNumber;
      _emailVerified = widget.profile?.emailVerified ?? _emailVerified;
    }
  }

  Future<void> _changePassword() async {
    var currentPassword = '';
    var newPassword = '';
    final formKey = GlobalKey<FormState>();
    final user = _service.auth.currentUser;
    final supportsPassword =
        user?.providerData.any(
          (provider) => provider.providerId == 'password',
        ) ??
        false;
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (supportsPassword)
                TextFormField(
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your current password.'
                      : null,
                  onSaved: (value) => currentPassword = value ?? '',
                )
              else
                const Text('We will email you a secure password setup link.'),
              if (supportsPassword)
                TextFormField(
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (value) => value == null || value.length < 6
                      ? 'Use at least 6 characters.'
                      : null,
                  onChanged: (value) => newPassword = value,
                  onSaved: (value) => newPassword = value ?? '',
                ),
              if (supportsPassword)
                TextFormField(
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                  validator: (value) =>
                      value != newPassword ? 'Passwords do not match.' : null,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(context, true);
              }
            },
            child: Text(supportsPassword ? 'Update password' : 'Send link'),
          ),
        ],
      ),
    );
    try {
      if (changed == true) {
        final passwordChanged = await _service.changeAccountPassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              passwordChanged
                  ? 'Password changed successfully.'
                  : 'Password setup link sent to your email.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not change password: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
    children: [
      const PageHeading(eyebrow: 'YOUR ACCOUNT', title: 'Profile'),
      if (_profileLoadError != null)
        ListTile(
          leading: const Icon(Icons.cloud_off_outlined, color: Colors.red),
          title: const Text('Profile details could not be refreshed.'),
          subtitle: Text(_profileLoadError!),
          trailing: IconButton(
            tooltip: 'Retry profile load',
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      const SizedBox(height: 17),
      SurfaceCard(
        child: Row(
          children: [
            const CircleAvatar(
              key: ValueKey('profile-avatar'),
              radius: 31,
              backgroundColor: Color(0xFFFFF3D6),
              backgroundImage: AssetImage('assets/images/avarta.png'),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName.isNotEmpty ? _displayName : 'NAYS Member',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.profile?.naysStudentId ??
                        'NAYS membership not linked',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit profile',
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const SectionLabel('Personal details'),
      const SizedBox(height: 8),
      SurfaceCard(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(widget.profile?.email ?? 'Not provided'),
              trailing: widget.profile == null
                  ? null
                  : _emailVerified
                  ? const Icon(Icons.verified_rounded, color: AppTheme.forest)
                  : TextButton(
                      onPressed: _verifyEmail,
                      child: const Text('Verify email'),
                    ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Phone'),
              subtitle: Text(
                _phoneNumber.isEmpty ? 'Not provided' : _phoneNumber,
              ),
            ),
            const Divider(height: 1),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.school_outlined),
              title: Text('NAYS membership'),
              subtitle: Text('Not linked to an approved member record'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      ListTile(
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.lock_outline_rounded),
        title: const Text('Change password'),
        onTap: _changePassword,
      ),
      const SizedBox(height: 8),
      ListTile(
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.settings_outlined),
        title: const Text('App settings'),
        onTap: () => widget.onOpen(const SettingsScreen()),
      ),
      const SizedBox(height: 12),
      const Center(
        child: Text(
          'Profile details are saved on this device.',
          style: TextStyle(color: AppTheme.muted, fontSize: 11),
        ),
      ),
    ],
  );
}
