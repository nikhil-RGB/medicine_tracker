import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'state/providers.dart';

class MedReminderApp extends ConsumerStatefulWidget {
  const MedReminderApp({super.key});

  @override
  ConsumerState<MedReminderApp> createState() => _MedReminderAppState();
}

class _MedReminderAppState extends ConsumerState<MedReminderApp> with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = buildRouter();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Recompute overdue (and refresh reminders) when the user returns.
    if (state == AppLifecycleState.resumed) {
      ref.read(clockProvider.notifier).tick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D5B));
    return MaterialApp.router(
      title: 'Medicine Reminders',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      routerConfig: _router,
    );
  }
}
