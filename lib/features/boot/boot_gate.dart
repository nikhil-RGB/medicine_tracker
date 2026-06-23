import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';

/// Splash + redirect gate: waits for services to boot, then routes to
/// onboarding, the disclaimer, or the app depending on stored flags.
class BootGate extends ConsumerWidget {
  const BootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(appServicesProvider);
    return boot.when(
      loading: () => const _Splash(),
      error: (e, st) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to start:\n$e', textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (services) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final s = services.settings;
          if (!s.onboardingComplete) {
            context.go('/onboarding');
          } else if (!s.disclaimerAccepted) {
            context.go('/disclaimer');
          } else {
            context.go('/today');
          }
        });
        return const _Splash();
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_rounded,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Medicine Reminders'),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
