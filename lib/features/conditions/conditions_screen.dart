import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../models/user_condition.dart';
import '../../state/providers.dart';
import 'condition_detail_screen.dart';
import 'condition_picker_screen.dart';

class ConditionsScreen extends ConsumerWidget {
  const ConditionsScreen({super.key});

  Future<void> _addCondition(BuildContext context) async {
    final created = await Navigator.of(context).push<UserCondition>(
      MaterialPageRoute(builder: (_) => const ConditionPickerScreen()),
    );
    if (created != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ConditionDetailScreen(conditionId: created.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Conditions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCondition(context),
        icon: const Icon(Icons.add),
        label: const Text('Add condition'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (snap) {
          final conditions = snap.activeConditions;
          if (conditions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.medication_outlined,
                        size: 72, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text('No conditions yet', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'Add a health condition, then the medicines you take for it.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: conditions.length,
            itemBuilder: (context, i) {
              final c = conditions[i];
              final count = snap.medicinesFor(c.id).where((m) => m.isActive).length;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorFromSeed(c.colorSeed),
                  child: Text(
                    c.name.isNotEmpty ? c.name.characters.first.toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(c.name),
                subtitle: Text(count == 1 ? '1 medicine' : '$count medicines'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ConditionDetailScreen(conditionId: c.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
