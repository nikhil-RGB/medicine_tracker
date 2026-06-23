import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      icon: Icons.checklist_rounded,
      title: 'Track your medicines',
      body: 'Group the medicines you take under the health conditions they treat, '
          'picking from a built-in list or adding your own.',
    ),
    (
      icon: Icons.notifications_active_outlined,
      title: 'Never miss a dose',
      body: 'Set the time and frequency for each medicine and get a reminder when '
          'a dose is due. Confirm it in the app and we log it for you.',
    ),
    (
      icon: Icons.calendar_month_outlined,
      title: 'See your whole plan',
      body: 'A simple calendar shows every dose, what it is for, and whether '
          'you have taken it.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(servicesProvider).settings.setOnboardingComplete(true);
    if (mounted) context.go('/disclaimer');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(s.icon, size: 96, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 32),
                        Text(s.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Text(s.body,
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (isLast) {
                      _finish();
                    } else {
                      _controller.nextPage(
                          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                    }
                  },
                  child: Text(isLast ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
