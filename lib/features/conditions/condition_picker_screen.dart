import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reference_models.dart';
import '../../models/user_condition.dart';
import '../../state/providers.dart';

/// Browse / search the bundled condition catalog (plus the user's own custom
/// conditions), or add a brand-new custom one. Pops with the created
/// [UserCondition].
class ConditionPickerScreen extends ConsumerStatefulWidget {
  const ConditionPickerScreen({super.key});

  @override
  ConsumerState<ConditionPickerScreen> createState() => _ConditionPickerScreenState();
}

class _ConditionPickerScreenState extends ConsumerState<ConditionPickerScreen> {
  String _query = '';

  Future<void> _pickReference(RefConditionIndex c) async {
    final created =
        await ref.read(dataProvider.notifier).addCondition(refId: c.id, name: c.name);
    if (mounted) Navigator.of(context).pop(created);
  }

  Future<void> _addCustom(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final created =
        await ref.read(dataProvider.notifier).addCondition(name: trimmed, isCustom: true);
    if (mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final reference = ref.read(servicesProvider).reference;
    final results = reference.searchConditions(_query);
    final q = _query.trim();
    final hasExact = results.any((c) => c.name.toLowerCase() == q.toLowerCase());

    return Scaffold(
      appBar: AppBar(title: const Text('Add condition')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search conditions',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (q.isNotEmpty && !hasExact)
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text('Add "$q" as a custom condition'),
                    onTap: () => _addCustom(q),
                  ),
                for (final c in results)
                  ListTile(
                    title: Text(c.name),
                    subtitle: c.aliases.isNotEmpty ? Text(c.aliases.join(', ')) : null,
                    onTap: () => _pickReference(c),
                  ),
                if (results.isEmpty && q.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Start typing to search conditions')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
