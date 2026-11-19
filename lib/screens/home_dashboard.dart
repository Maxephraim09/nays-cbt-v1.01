import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../auth_user_profile.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/nays_widgets.dart';
import 'cbt_screens.dart';
import 'info_screens.dart';
import 'reminders_screen.dart';

class HomeDashboardTab extends StatelessWidget {
  const HomeDashboardTab({
    required this.controller,
    required this.onTab,
    required this.onOpen,
    this.profile,
    this.service,
    super.key,
  });

  final DemoAppController controller;
  final ValueChanged<int> onTab;
  final ValueChanged<Widget> onOpen;
  final AuthUserProfile? profile;
  final FirestoreCbtService? service;

  static const _shortcuts = [
    ('Available\nExaminations', 'View exams', Icons.fact_check_rounded),
    ('My Results', 'Check scores', Icons.bar_chart_rounded),
    ('JAMB\nSimulation', 'Start examination', Icons.edit_note_rounded),
    ('Settings', 'App preferences', Icons.settings_rounded),
    ('Support', 'Get help', Icons.support_agent_rounded),
    ('Reminders', 'Study prompts', Icons.alarm_rounded),
  ];

  static const _lightTileColors = [
    Color(0xFFD8F6F0),
    Color(0xFFECE4FF),
    Color(0xFFFFE9D9),
    Color(0xFFDDF4F4),
    Color(0xFFE1EDFF),
    Color(0xFFFFE2EA),
  ];
  static const _darkTileColors = [
    Color(0xFF183D35),
    Color(0xFF302746),
    Color(0xFF493125),
    Color(0xFF1D4140),
    Color(0xFF233850),
    Color(0xFF472B37),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColors = isDark ? _darkTileColors : _lightTileColors;
    return CustomScrollView(
      key: const ValueKey('home-dashboard'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(17, 7, 17, 24),
          sliver: SliverList.list(
            children: [
              _header(context),
              const SizedBox(height: 17),
              _welcomeBanner(context, profile),
              const SizedBox(height: 14),
              _examHero(context),
              const SizedBox(height: 12),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ShortcutTile(
                title: _shortcuts[index].$1,
                subtitle: _shortcuts[index].$2,
                icon: _shortcuts[index].$3,
                color: tileColors[index],
                onTap: () => _openShortcut(context, index),
              ),
              childCount: _shortcuts.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisExtent: 142,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(17, 14, 17, 0),
          sliver: SliverList.list(
            children: [
              _notice(context),
              const SizedBox(height: 14),
              _supportBand(context),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'NAYS CBT · Secure exam practice',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) => Row(
    children: [
      const BrandMark(size: 48),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'National Association of Yungur Students',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.brand(context),
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'BƏNA NDO FINI',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: .7,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Notifications',
        onPressed: () => onOpen(NotificationsScreen(service: service)),
        icon: const Icon(Icons.notifications_rounded),
      ),
    ],
  );

  Widget _welcomeBanner(BuildContext context, AuthUserProfile? profile) {
    final firstName = _firstName(profile);
    final accountLabel = profile == null
        ? 'Guest account'
        : profile.naysMembershipStatus;
    return Container(
      constraints: const BoxConstraints(minHeight: 128),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF10A982), Color(0xFF075344)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.forest.withValues(alpha: .14),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const CircleAvatar(
              key: ValueKey('home-avatar'),
              radius: 39,
              backgroundColor: Color(0xFFD9F6EE),
              backgroundImage: AssetImage('assets/images/avarta.png'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Hello, $firstName!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile == null ? 'NAYS Student' : 'Firebase account',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        accountLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            flex: 2,
            child: Text(
              'Excel Today,\nLead Tomorrow',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _firstName(AuthUserProfile? profile) {
    final name = profile?.displayName.trim() ?? '';
    if (name.isEmpty) return 'Student';
    return name.split(RegExp(r'\s+')).first;
  }

  Widget _examHero(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: SizedBox(
      height: 224,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/hero.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF00A3D33),
                  Color(0xB80A3D33),
                  Color(0x12123A0A),
                ],
                stops: [0, .56, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 17),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF069D70).withValues(alpha: .9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'CBT EXAMINATION',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 11),
                      const Text(
                        'Take Your\nNAYS CBT Exam',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.04,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Test · Learn · Excel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _openExamAccess,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.deepGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          minimumSize: const Size(0, 42),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text(
                          'Start Exam',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  flex: 4,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(
                      Icons.quiz_rounded,
                      size: 94,
                      color: Color(0xFFB7F5E5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HeroDot(active: true),
                SizedBox(width: 7),
                _HeroDot(active: false),
                SizedBox(width: 7),
                _HeroDot(active: false),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _notice(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      key: const ValueKey('home-notice'),
      borderRadius: BorderRadius.circular(18),
      onTap: () => onOpen(NotificationsScreen(service: service)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFD9F6EE),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: AppTheme.forest,
                size: 26,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Announcements',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'View current updates published by NAYS.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.brand(context),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _supportBand(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF087D66), Color(0xFF063E36)],
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.white,
          backgroundImage: const AssetImage('assets/images/avarta.png'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Need Help?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Contact our support team',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 7,
                children: [
                  _ContactChip(
                    icon: Icons.call_rounded,
                    label: 'Call',
                    uri: Uri(scheme: 'tel', path: '08161595906'),
                  ),
                  _ContactChip(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    uri: Uri(scheme: 'mailto', path: 'mgtechs09@gmail.com'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _openShortcut(BuildContext context, int index) {
    switch (index) {
      case 0:
        _openExamAccess();
      case 1:
        onOpen(HistoryScreen(service: service));
      case 2:
        onOpen(
          JambSimulationWaitingScreen(
            controller: controller,
            service: service ?? FirestoreCbtService(),
            profile: profile,
          ),
        );
      case 3:
        onTab(2);
      case 4:
        onOpen(const SupportScreen());
      case 5:
        onOpen(const RemindersScreen());
    }
  }

  void _openExamAccess() => onOpen(
    CbtAccessScreen(
      controller: controller,
      service: service ?? FirestoreCbtService(),
    ),
  );
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 10, 7, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 33, color: AppTheme.brand(context)),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HeroDot extends StatelessWidget {
  const _HeroDot({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: active ? 17 : 7,
    height: 7,
    decoration: BoxDecoration(
      color: active ? Colors.white : Colors.white54,
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({
    required this.icon,
    required this.label,
    required this.uri,
  });
  final IconData icon;
  final String label;
  final Uri uri;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = isDark ? Colors.white : AppTheme.forest;
    final backgroundColor = isDark
        ? Colors.white.withValues(alpha: .14)
        : Colors.white;
    return ActionChip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, color: foregroundColor, size: 15),
      label: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: backgroundColor,
      side: BorderSide.none,
      onPressed: () async {
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open the support app on this device.'),
            ),
          );
        }
      },
    );
  }
}
