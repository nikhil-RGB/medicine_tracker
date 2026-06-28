import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/date_x.dart' show dateKey;
import '../../models/dose_occurrence.dart';
import '../../services/dose_expander.dart';
import '../../state/providers.dart';
import '../../widgets/calendar_mascot.dart';
import 'day_detail_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<DoseOccurrence> _dosesFor(DateTime day) {
    final snap = ref.read(dataProvider).valueOrNull;
    if (snap == null) return const [];
    final now = ref.read(clockProvider);
    return DoseExpander.expandAll(
      medicines: snap.medicines,
      conditionsById: snap.conditionsById,
      from: day,
      to: day,
      eventsByOccurrence: snap.eventsByOccurrence,
      now: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when data or the clock changes.
    ref.watch(dataProvider);
    ref.watch(clockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Stack(
        children: [
          Column(
        children: [
          TableCalendar<DoseOccurrence>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            selectedDayPredicate: (d) => _selectedDay != null && isSameDay(d, _selectedDay),
            eventLoader: _dosesFor,
            onPageChanged: (focused) => _focusedDay = focused,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CalendarDayDetailScreen(dayKey: dateKey(selected)),
                ),
              );
            },
            calendarBuilders: CalendarBuilders<DoseOccurrence>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                final Color color;
                if (events.any((o) => o.state == DoseState.overdue)) {
                  color = Theme.of(context).colorScheme.error;
                } else if (events.any((o) => o.state == DoseState.pending)) {
                  color = Theme.of(context).colorScheme.primary;
                } else {
                  color = Colors.green.shade600;
                }
                return Positioned(
                  bottom: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          const Expanded(child: _CalendarLegend()),
        ],
          ),
          const Positioned(
            right: 4,
            bottom: 8,
            child: CalendarMascot(),
          ),
        ],
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
        );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app_outlined, size: 28),
          const SizedBox(height: 8),
          const Text('Tap a day to see its doses'),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              dot(Theme.of(context).colorScheme.error, 'Overdue'),
              dot(Theme.of(context).colorScheme.primary, 'Upcoming'),
              dot(Colors.green.shade600, 'All done'),
            ],
          ),
        ],
      ),
    );
  }
}
