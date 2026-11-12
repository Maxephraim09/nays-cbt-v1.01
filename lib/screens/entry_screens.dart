import 'dart:async';
import 'package:flutter/material.dart';
import '../app.dart';
import '../theme/app_theme.dart';
import '../widgets/nays_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.forest, AppTheme.deepGreen],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const BrandMark(size: 100),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'NAYS CBT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'LEARN WELL. SHOW WHAT YOU KNOW.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 38),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.gold,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              bottom: 25,
              left: 0,
              right: 0,
              child: Text(
                'A NAYS learning experience',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onFinished, super.key});
  final VoidCallback onFinished;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;
  static const _slides = [
    (
      'GET READY TO GROW',
      'Your next big\nstep starts here.',
      'A focused space to prepare, practise and build the confidence to reach your goals.',
      'assets/images/hero.jpg',
      Icons.school_rounded,
    ),
    (
      'PRACTISE WITH PURPOSE',
      'Make every\nquestion count.',
      'Work through familiar multiple-choice practice and learn from each answer.',
      'assets/images/debate.jpg',
      Icons.edit_note_rounded,
    ),
    (
      'TRACK YOUR PROGRESS',
      'See how far\nyou can go.',
      'Keep your learning organised with subject choices, progress and practice history.',
      'assets/images/event_forum.jpg',
      Icons.insights_rounded,
    ),
    (
      'YOUR JOURNEY, YOUR PACE',
      'Walk into your\nnext exam ready.',
      'Start with a short local demo, explore the tools and make the app yours.',
      'assets/images/student_volunteers.jpg',
      Icons.flag_rounded,
    ),
  ];
  Future<void> _finish() async {
    await AppScope.of(context).completeOnboarding();
    if (mounted) {
      widget.onFinished();
    }
  }

  void _next() {
    if (_index == _slides.length - 1) {
      unawaited(_finish());
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 16, 8),
              child: Row(
                children: [
                  const BrandMark(size: 38),
                  const SizedBox(width: 10),
                  const Text(
                    'NAYS CBT',
                    style: TextStyle(
                      color: AppTheme.forest,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _finish, child: const Text('Skip')),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: SizedBox(
                            height: MediaQuery.sizeOf(context).height * .40,
                            width: double.infinity,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(slide.$4, fit: BoxFit.cover),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Color(0x990F3A2E),
                                      ],
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.gold,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        slide.$5,
                                        color: AppTheme.deepGreen,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        Text(
                          slide.$1,
                          style: const TextStyle(
                            color: AppTheme.forest,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          slide.$2,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          slide.$3,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppTheme.muted),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        width: index == _index ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: index == _index
                              ? AppTheme.forest
                              : const Color(0xFFD8E0DB),
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 58,
                    height: 54,
                    child: FilledButton(
                      key: const ValueKey('onboarding-next'),
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.forest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Icon(
                        _index == _slides.length - 1
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
