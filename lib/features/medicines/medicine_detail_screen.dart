import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/schedule_summary.dart';
import '../../models/intake_event.dart';
import '../../models/schedule.dart';
import '../../services/adherence.dart';
import '../../state/providers.dart';
import 'add_edit_medicine_screen.dart';

final DateFormat _histFmt = DateFormat('EEE d MMM, h:mm a');

class MedicineDetailScreen extends ConsumerWidget {
  const MedicineDetailScreen({super.key, required this.medicineId});

  final String medicineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(dataProvider).valueOrNull;
    final now = ref.watch(clockProvider);
    if (snap == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final med = snap.medicineById(medicineId);
    if (med == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Medicine not found')));
    }
    final cond = snap.conditionById(med.conditionId);
    final stats = cond == null
        ? const AdherenceStats()
        : AdherenceService.forMedicine(
            med: med, condition: cond, eventsByOccurrence: snap.eventsByOccurrence, now: now);

    final history = snap.events.where((e) => e.medicineId == medicineId).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(med.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AddEditMedicineScreen(
                conditionId: med.conditionId,
                initialName: med.name,
                refDrugId: med.refDrugId,
                isCustom: med.isCustom,
                existing: med,
              ),
            )),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              final notifier = ref.read(dataProvider.notifier);
              if (v == 'stop') {
                await notifier.stopMedicine(med.id);
              } else if (v == 'delete') {
                final ok = await _confirmDelete(context);
                if (ok) {
                  await notifier.deleteMedicine(med.id);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (_) => [
              if (med.isActive && med.courseType != CourseType.prn)
                const PopupMenuItem(value: 'stop', child: Text('Stop taking')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Chip(label: Text(courseTypeBadge(med.courseType))),
            const SizedBox(width: 8),
            if (!med.isActive) const Chip(label: Text('Stopped')),
          ]),
          const SizedBox(height: 12),
          Text(scheduleSummary(med), style: Theme.of(context).textTheme.bodyLarge),
          if (med.dosageNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Note: ${med.dosageNote}'),
            ),
          const SizedBox(height: 16),
          _AdherenceCard(stats: stats),
          const SizedBox(height: 16),
          Text('History', style: Theme.of(context).textTheme.titleMedium),
          if (history.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('No doses logged yet.'))
          else
            for (final e in history) _historyTile(context, e),
        ],
      ),
    );
  }

  Widget _historyTile(BuildContext context, IntakeEvent e) {
    final (IconData icon, Color color, String label) = switch (e.status) {
      IntakeStatus.taken => (Icons.check_circle, Colors.green, 'Taken'),
      IntakeStatus.prnTaken => (Icons.check_circle, Colors.green, 'Taken (as needed)'),
      IntakeStatus.skipped => (Icons.do_not_disturb_on, Colors.grey, 'Skipped'),
    };
    final when = DateTime.tryParse(e.recordedAt)?.toLocal();
    final scheduled = e.scheduledFor != null ? DateTime.tryParse(e.scheduledFor!) : null;
    final parts = <String>[
      if (when != null) _histFmt.format(when),
      if (scheduled != null) 'scheduled ${DateFormat('h:mm a').format(scheduled)}',
    ];
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(label),
      subtitle: parts.isNotEmpty ? Text(parts.join(' · ')) : null,
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete medicine?'),
        content: const Text(
            'This removes the medicine and its schedule. Logged history stays unless you wipe data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.stats});

  final AdherenceStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.courseType == CourseType.prn) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.history),
            const SizedBox(width: 12),
            Text('Taken ${stats.prnCount} time${stats.prnCount == 1 ? '' : 's'}'),
          ]),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stats.isFinite) ...[
              Text('${stats.taken} of ${stats.totalExpected} doses taken',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: stats.progress, minHeight: 8),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 20, runSpacing: 8, children: [
                _stat('Taken', stats.taken),
                _stat('Remaining', stats.remaining),
                _stat('Overdue', stats.overdue),
                _stat('Skipped', stats.skipped),
              ]),
            ] else ...[
              Text('Last ${AdherenceService.ongoingWindowDays} days',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('${(stats.windowedRate * 100).round()}% taken on time'),
              const SizedBox(height: 12),
              Wrap(spacing: 20, runSpacing: 8, children: [
                _stat('Taken', stats.taken),
                _stat('Overdue', stats.overdue),
                _stat('Skipped', stats.skipped),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}
