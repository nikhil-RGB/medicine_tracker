import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_x.dart';
import '../../models/prescribed_medicine.dart';
import '../../models/schedule.dart';
import '../../state/providers.dart';

/// Specify how a medicine is taken: course type, start/duration, and an exact
/// time for each daily dose. Reused for both add and edit. Pops with the saved
/// [PrescribedMedicine].
class AddEditMedicineScreen extends ConsumerStatefulWidget {
  const AddEditMedicineScreen({
    super.key,
    required this.conditionId,
    required this.initialName,
    this.refDrugId,
    this.isCustom = false,
    this.existing,
  });

  final String conditionId;
  final String initialName;
  final String? refDrugId;
  final bool isCustom;
  final PrescribedMedicine? existing;

  @override
  ConsumerState<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends ConsumerState<AddEditMedicineScreen> {
  late CourseType _course;
  late DateTime _startDate;
  final _durationCtrl = TextEditingController(text: '7');
  final _noteCtrl = TextEditingController();
  List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _course = e.courseType;
      _noteCtrl.text = e.dosageNote ?? '';
      final r = e.schedule;
      if (r != null) {
        _startDate = parseDateKey(r.startDate);
        if (r.durationDays != null) _durationCtrl.text = r.durationDays.toString();
        if (r.slots.isNotEmpty) {
          _times = r.slots.map((s) => TimeOfDay(hour: s.hour, minute: s.minute)).toList();
        }
      } else {
        _startDate = DateTime.now();
      }
    } else {
      _course = CourseType.fixed;
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isPrn => _course == CourseType.prn;
  bool get _isFixed => _course == CourseType.fixed;

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _editTime(int index) async {
    final t = await showTimePicker(context: context, initialTime: _times[index]);
    if (t != null) setState(() => _times[index] = t);
  }

  void _setFrequency(int target) {
    setState(() {
      final n = target.clamp(1, 12);
      if (n > _times.length) {
        while (_times.length < n) {
          _times.add(TimeOfDay(hour: (8 + _times.length * 4) % 24, minute: 0));
        }
      } else {
        _times = _times.sublist(0, n);
      }
    });
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    final notifier = ref.read(dataProvider.notifier);
    ScheduleRule? rule;

    if (!_isPrn) {
      if (_times.isEmpty) {
        _toast('Add at least one time');
        return;
      }
      final duration = _isFixed ? int.tryParse(_durationCtrl.text.trim()) : null;
      if (_isFixed && (duration == null || duration <= 0)) {
        _toast('Enter a valid number of days');
        return;
      }
      final seen = <int>{};
      final sorted = [..._times]
        ..sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
      final slots = <DoseSlot>[];
      for (final t in sorted) {
        if (seen.add(t.hour * 60 + t.minute)) {
          slots.add(DoseSlot(hour: t.hour, minute: t.minute));
        }
      }
      rule = ScheduleRule(
        startDate: dateKey(_startDate),
        durationDays: _isFixed ? duration : null,
        slots: slots,
      );
    }

    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final PrescribedMedicine saved;
    if (widget.existing != null) {
      saved = widget.existing!.copyWith(
        courseType: _course,
        schedule: rule,
        clearSchedule: _isPrn,
        dosageNote: note,
        clearDosageNote: note == null,
      );
      await notifier.updateMedicine(saved);
    } else {
      saved = await notifier.createMedicine(
        conditionId: widget.conditionId,
        name: widget.initialName,
        refDrugId: widget.refDrugId,
        isCustom: widget.isCustom,
        dosageNote: note,
        courseType: _course,
        schedule: rule,
      );
    }
    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.existing?.name ?? widget.initialName;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add medicine' : 'Edit medicine')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text('How is it taken?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<CourseType>(
            segments: const [
              ButtonSegment(value: CourseType.fixed, label: Text('Fixed'), icon: Icon(Icons.event)),
              ButtonSegment(
                  value: CourseType.ongoing,
                  label: Text('Ongoing'),
                  icon: Icon(Icons.all_inclusive)),
              ButtonSegment(
                  value: CourseType.prn, label: Text('As needed'), icon: Icon(Icons.front_hand)),
            ],
            selected: {_course},
            onSelectionChanged: (s) => setState(() => _course = s.first),
          ),
          const SizedBox(height: 16),
          if (_isPrn)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'As-needed medicines have no schedule and no reminders. You log '
                  'them yourself from the Today screen when you take one.',
                ),
              ),
            )
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Start date'),
              subtitle: Text(prettyDate(_startDate)),
              trailing: TextButton(onPressed: _pickStart, child: const Text('Change')),
            ),
            if (_isFixed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextField(
                  controller: _durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Take for how many days?',
                    border: OutlineInputBorder(),
                    suffixText: 'days',
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('Times per day: ${_times.length}',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                IconButton(
                  onPressed: _times.length > 1 ? () => _setFrequency(_times.length - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  onPressed: _times.length < 12 ? () => _setFrequency(_times.length + 1) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            for (var i = 0; i < _times.length; i++)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.alarm),
                  title: Text('Dose ${i + 1}'),
                  trailing: Text(_times[i].format(context),
                      style: Theme.of(context).textTheme.titleMedium),
                  onTap: () => _editTime(i),
                ),
              ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional) — e.g. "1 tablet, after food"',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(widget.existing == null ? 'Add medicine' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
