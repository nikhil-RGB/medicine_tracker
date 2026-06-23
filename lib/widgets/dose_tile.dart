import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/palette.dart';
import '../models/dose_occurrence.dart';

final DateFormat _timeFmt = DateFormat('h:mm a');

class DoseTile extends StatelessWidget {
  const DoseTile({super.key, required this.occurrence, this.onTap, this.subtitleCondition = true});

  final DoseOccurrence occurrence;
  final VoidCallback? onTap;
  final bool subtitleCondition;

  @override
  Widget build(BuildContext context) {
    final o = occurrence;
    final color = colorFromSeed(o.colorSeed);
    final (IconData icon, Color iconColor, String? statusLabel) = switch (o.state) {
      DoseState.taken => (Icons.check_circle, Colors.green.shade600, 'Taken'),
      DoseState.skipped => (Icons.do_not_disturb_on, Colors.grey, 'Skipped'),
      DoseState.overdue => (Icons.error, Theme.of(context).colorScheme.error, 'Overdue'),
      DoseState.pending => (Icons.schedule, Theme.of(context).colorScheme.outline, null),
    };
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(o.medicineName),
      subtitle: Text(subtitleCondition
          ? '${o.conditionName} · ${_timeFmt.format(o.dueAt)}'
          : _timeFmt.format(o.dueAt)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(icon, color: iconColor, size: 22),
          if (statusLabel != null)
            Text(statusLabel, style: TextStyle(fontSize: 11, color: iconColor)),
        ],
      ),
      onTap: onTap,
    );
  }
}
