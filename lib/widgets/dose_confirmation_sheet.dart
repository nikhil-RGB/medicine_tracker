import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/date_x.dart';
import '../core/palette.dart';
import '../models/dose_occurrence.dart';
import '../models/intake_event.dart';
import '../state/providers.dart';

final DateFormat _timeFmt = DateFormat('h:mm a');

Future<void> showDoseConfirmationSheet(BuildContext context, DoseOccurrence occurrence) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => _DoseConfirmationSheet(occurrence: occurrence),
  );
}

class _DoseConfirmationSheet extends ConsumerWidget {
  const _DoseConfirmationSheet({required this.occurrence});

  final DoseOccurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = occurrence;
    final color = colorFromSeed(o.colorSeed);
    final overdue = o.state == DoseState.overdue;
    final done = o.state == DoseState.taken || o.state == DoseState.skipped;
    final notifier = ref.read(dataProvider.notifier);

    Future<void> close() async {
      if (context.mounted) Navigator.of(context).pop();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(o.medicineName, style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('For ${o.conditionName}', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text('Scheduled ${_timeFmt.format(o.dueAt)} · ${prettyDate(o.dueAt)}',
                style: Theme.of(context).textTheme.bodySmall),
            if (overdue)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Overdue',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 20),
            if (!done) ...[
              FilledButton.icon(
                onPressed: () async {
                  await notifier.markDose(o, IntakeStatus.taken);
                  await close();
                },
                icon: const Icon(Icons.check),
                label: const Text('Mark as taken'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await notifier.markDose(o, IntakeStatus.skipped);
                  await close();
                },
                icon: const Icon(Icons.close),
                label: const Text('Skip this dose'),
              ),
            ] else ...[
              Center(
                child: Text(o.state == DoseState.taken ? 'Marked as taken' : 'Marked as skipped'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await notifier.undoOccurrence(o.occurrenceId);
                  await close();
                },
                icon: const Icon(Icons.undo),
                label: const Text('Undo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
