import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/prescribed_medicine.dart';
import '../../models/reference_models.dart';
import '../../state/providers.dart';
import 'add_edit_medicine_screen.dart';

/// Within a condition, shows that condition's typical medicines and lets the
/// user search the whole drug catalog or add a custom one. Advances to the
/// schedule form, then pops with the created [PrescribedMedicine].
class MedicinePickerScreen extends ConsumerStatefulWidget {
  const MedicinePickerScreen({super.key, required this.conditionId});

  final String conditionId;

  @override
  ConsumerState<MedicinePickerScreen> createState() => _MedicinePickerScreenState();
}

class _MedicinePickerScreenState extends ConsumerState<MedicinePickerScreen> {
  String _query = '';
  List<RefDrug> _typical = const [];
  List<RefDrug> _results = const [];
  bool _loadingTypical = true;

  @override
  void initState() {
    super.initState();
    _loadTypical();
  }

  Future<void> _loadTypical() async {
    final snap = ref.read(dataProvider).valueOrNull;
    final reference = ref.read(servicesProvider).reference;
    final cond = snap?.conditionById(widget.conditionId);
    if (cond?.refId != null) {
      RefConditionIndex? refCond;
      for (final c in reference.index.conditions) {
        if (c.id == cond!.refId) {
          refCond = c;
          break;
        }
      }
      if (refCond != null) {
        _typical = await reference.drugsForCondition(refCond);
      }
    }
    if (mounted) setState(() => _loadingTypical = false);
  }

  Future<void> _runSearch(String q) async {
    setState(() => _query = q);
    if (q.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    final res = await ref.read(servicesProvider).reference.searchAllDrugs(q);
    if (mounted && q == _query) setState(() => _results = res);
  }

  Future<void> _select({required String name, String? refDrugId, bool isCustom = false}) async {
    final med = await Navigator.of(context).push<PrescribedMedicine>(
      MaterialPageRoute(
        builder: (_) => AddEditMedicineScreen(
          conditionId: widget.conditionId,
          initialName: name,
          refDrugId: refDrugId,
          isCustom: isCustom,
        ),
      ),
    );
    if (med != null && mounted) Navigator.of(context).pop(med);
  }

  Future<void> _addCustom() async {
    final controller = TextEditingController(text: _query.trim());
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add custom medicine'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Medicine name (no dosage)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Next'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _select(name: name, isCustom: true);
    }
  }

  Widget _drugTile(RefDrug d) => ListTile(
        leading: const Icon(Icons.medication_outlined),
        title: Text(d.name),
        subtitle: d.aliases.isNotEmpty ? Text(d.aliases.join(', ')) : null,
        onTap: () => _select(name: d.name, refDrugId: d.id),
      );

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Add medicine')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search all medicines',
                border: OutlineInputBorder(),
              ),
              onChanged: _runSearch,
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: Text(searching
                      ? 'Add "${_query.trim()}" as a custom medicine'
                      : 'Add a medicine not listed'),
                  onTap: _addCustom,
                ),
                const Divider(),
                if (searching) ...[
                  for (final d in _results) _drugTile(d),
                  if (_results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No matches')),
                    ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('TYPICAL FOR THIS CONDITION',
                        style: Theme.of(context).textTheme.labelMedium),
                  ),
                  if (_loadingTypical)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_typical.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Search above to find any medicine, or add a custom one.'),
                    )
                  else
                    for (final d in _typical) _drugTile(d),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
