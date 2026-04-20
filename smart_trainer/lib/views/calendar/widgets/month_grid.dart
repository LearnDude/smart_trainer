import 'package:flutter/material.dart';
import '../../../models/planned_workout.dart';
import '../../../models/session_result.dart';
import '../../../providers/calendar_provider.dart';
import 'day_cell.dart';

class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.focusedMonth,
    required this.dayMap,
    required this.onSessionTap,
    required this.onPlannedTap,
  });

  final DateTime focusedMonth;
  final Map<String, CalendarDay> dayMap;
  final void Function(SessionResult) onSessionTap;
  final void Function(PlannedWorkout) onPlannedTap;

  static const _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context) {
    final days = _buildDays();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return Column(
      children: [
        // Weekday header
        Row(
          children: _weekdays
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        // Day grid
        ...List.generate((days.length / 7).ceil(), (rowIndex) {
          final rowDays = days.skip(rowIndex * 7).take(7).toList();
          return Row(
            children: rowDays.map((day) {
              if (day == null) return const Expanded(child: SizedBox(height: 52));
              final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              return Expanded(
                child: SizedBox(
                  height: 52,
                  child: DayCell(
                    day: day,
                    calendarDay: dayMap[key],
                    isToday: key == todayKey,
                    isCurrentMonth: day.month == focusedMonth.month,
                    onSessionTap: onSessionTap,
                    onPlannedTap: onPlannedTap,
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  List<DateTime?> _buildDays() {
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    // Monday = 1, so offset = weekday - 1 (Mon=0, Tue=1, ... Sun=6)
    final startOffset = firstOfMonth.weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
    final totalCells = ((startOffset + daysInMonth) / 7).ceil() * 7;

    return List.generate(totalCells, (i) {
      final dayNum = i - startOffset + 1;
      if (dayNum < 1 || dayNum > daysInMonth) return null;
      return DateTime(focusedMonth.year, focusedMonth.month, dayNum);
    });
  }
}
