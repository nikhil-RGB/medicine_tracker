import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_x.dart';
import '../../state/providers.dart';
import '../../widgets/dose_confirmation_sheet.dart';
import '../../widgets/dose_tile.dart';

class CalendarDayDetailScreen extends ConsumerWidget {
  const CalendarDayDetailScreen({super.key, required this.dayKey});

  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doses = ref.watch(dosesForDayProvider(dayKey));
    final day = parseDateKey(dayKey);

    return Scaffold(
      appBar: AppBar(title: Text(prettyDate(day))),
      body: doses.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No doses scheduled this day', textAlign: TextAlign.center),
              ),
            )
          : ListView.builder(
              itemCount: doses.length,
              itemBuilder: (context, i) {
                final o = doses[i];
                return DoseTile(
                  occurrence: o,
                  onTap: () => showDoseConfirmationSheet(context, o),
                );
              },
            ),
    );
  }
}
