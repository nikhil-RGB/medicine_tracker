import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/schedule_summary.dart';
import '../../models/prescribed_medicine.dart';
import '../../state/providers.dart';
import '../medicines/medicine_detail_screen.dart';
import '../medicines/medicine_picker_screen.dart';

class ConditionDetailScreen extends ConsumerWidget {
  const ConditionDetailScreen({super.key, required this.conditionId});

  final String conditionId;

  Future<void> _addMedicine(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<PrescribedMedicine>(
      MaterialPageRoute(builder: (_) => MedicinePickerScreen(conditionId: conditionId)),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Added ${result.name}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(dataProvider).valueOrNull;
    final condition = snap?.conditionById(conditionId);

    if (snap == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (condition == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This condition is no longer available.')),
      );
    }

    final meds = snap.medicinesFor(conditionId);
    final active = meds.where((m) => m.isActive).toList();
    final stopped = meds.where((m) => !m.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(condition.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'archive') {
                await ref.read(dataProvider.notifier).archiveCondition(conditionId);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'archive', child: Text('Archive condition')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addMedicine(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add medicine'),
      ),
      body: meds.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.medication_liquid_outlined,
                        size: 64, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    const Text('No medicines yet for this condition.',
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final m in active)
                  _MedicineTile(condition: condition.colorSeed, medicine: m),
                if (stopped.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('STOPPED',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  for (final m in stopped)
                    _MedicineTile(condition: condition.colorSeed, medicine: m, stopped: true),
                ],
              ],
            ),
    );
  }
}

class _MedicineTile extends StatelessWidget {
  const _MedicineTile({required this.condition, required this.medicine, this.stopped = false});

  final int condition;
  final PrescribedMedicine medicine;
  final bool stopped;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: stopped ? Theme.of(context).colorScheme.outlineVariant : colorFromSeed(condition),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(medicine.name,
          style: stopped ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
      subtitle: Text(scheduleSummary(medicine)),
      trailing: Chip(
        label: Text(courseTypeBadge(medicine.courseType), style: const TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MedicineDetailScreen(medicineId: medicine.id)),
      ),
    );
  }
}
