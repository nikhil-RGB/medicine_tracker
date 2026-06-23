import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../models/dose_occurrence.dart';
import '../../models/schedule.dart';
import '../../state/providers.dart';
import '../../widgets/dose_confirmation_sheet.dart';
import '../../widgets/dose_tile.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool _didInit = false;

  Future<void> _initOnce() async {
    if (_didInit) return;
    _didInit = true;
    // Build the data, request notification permission, and seed reminders.
    await ref.read(dataProvider.future);
    final notifier = ref.read(dataProvider.notifier);
    await notifier.requestNotificationPermission();
    await notifier.reconcileNow();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _initOnce());

    final async = ref.watch(dataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _logPrn(context),
        icon: const Icon(Icons.add),
        label: const Text('Log dose'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (_) {
          final doses = ref.watch(todayDosesProvider);
          if (doses.isEmpty) return const _EmptyToday();

          final overdue = doses.where((o) => o.state == DoseState.overdue).toList();
          final upcoming = doses.where((o) => o.state == DoseState.pending).toList();
          final done = doses
              .where((o) => o.state == DoseState.taken || o.state == DoseState.skipped)
              .toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (overdue.isNotEmpty)
                _Section(
                  title: 'Overdue',
                  color: Theme.of(context).colorScheme.error,
                  children: overdue,
                ),
              if (upcoming.isNotEmpty) _Section(title: 'Upcoming', children: upcoming),
              if (done.isNotEmpty) _Section(title: 'Done', children: done),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logPrn(BuildContext context) async {
    final snap = ref.read(dataProvider).valueOrNull;
    if (snap == null) return;
    final prnMeds = snap.medicines
        .where((m) => m.courseType == CourseType.prn && m.isActive)
        .toList();

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        if (prnMeds.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No as-needed (PRN) medicines yet.\n\nAdd a medicine with the '
              '"As needed" course type to log doses here.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Log an as-needed dose'),
              ),
              for (final m in prnMeds)
                ListTile(
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorFromSeed(
                          snap.conditionById(m.conditionId)?.colorSeed ?? 0xFF6750A4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(m.name),
                  subtitle: Text(snap.conditionById(m.conditionId)?.name ?? ''),
                  onTap: () async {
                    await ref.read(dataProvider.notifier).logPrn(m);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logged ${m.name}')),
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.color});

  final String title;
  final List<DoseOccurrence> children;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color ?? Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        for (final o in children)
          Builder(
            builder: (context) => _ConfirmableDoseTile(occurrence: o),
          ),
      ],
    );
  }
}

class _ConfirmableDoseTile extends StatelessWidget {
  const _ConfirmableDoseTile({required this.occurrence});
  final DoseOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    return DoseTile(
      occurrence: occurrence,
      onTap: () => showDoseConfirmationSheet(context, occurrence),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined,
                size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No doses scheduled today',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Add a health condition and the medicines you take for it to start '
              'tracking doses.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/conditions'),
              icon: const Icon(Icons.add),
              label: const Text('Add a condition'),
            ),
          ],
        ),
      ),
    );
  }
}
