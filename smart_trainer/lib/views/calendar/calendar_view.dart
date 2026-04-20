import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/calendar_provider.dart';
import 'widgets/month_grid.dart';
import 'widgets/nlp_schedule_bar.dart';
import 'widgets/planned_detail_sheet.dart';
import 'widgets/session_detail_sheet.dart';

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() => setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
      });

  @override
  Widget build(BuildContext context) {
    final dayMap = ref.watch(calendarDayMapProvider);

    return Column(
      children: [
        _MonthNavBar(
          focusedMonth: _focusedMonth,
          onPrev: _prevMonth,
          onNext: _nextMonth,
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: MonthGrid(
              focusedMonth: _focusedMonth,
              dayMap: dayMap,
              onSessionTap: (s) => showSessionDetailSheet(context, s),
              onPlannedTap: (p) => showPlannedDetailSheet(context, p),
            ),
          ),
        ),
        const Divider(height: 1),
        const NlpScheduleBar(),
      ],
    );
  }
}

class _MonthNavBar extends StatelessWidget {
  const _MonthNavBar({
    required this.focusedMonth,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime focusedMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
          tooltip: 'Previous month',
        ),
        Text(
          '${_monthNames[focusedMonth.month]} ${focusedMonth.year}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
          tooltip: 'Next month',
        ),
      ],
    );
  }
}
