import 'package:flutter/material.dart';
import '../../../models/planned_workout.dart';
import '../../../models/session_result.dart';
import '../../../providers/calendar_provider.dart';

Color _rpeColor(int rpe) {
  if (rpe <= 2) return Colors.green;
  if (rpe == 3) return Colors.amber;
  return Colors.redAccent;
}

class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.calendarDay,
    required this.isToday,
    required this.isCurrentMonth,
    required this.onSessionTap,
    required this.onPlannedTap,
  });

  final DateTime day;
  final CalendarDay? calendarDay;
  final bool isToday;
  final bool isCurrentMonth;
  final void Function(SessionResult) onSessionTap;
  final void Function(PlannedWorkout) onPlannedTap;

  @override
  Widget build(BuildContext context) {
    final sessions = calendarDay?.sessions ?? [];
    final planned = calendarDay?.planned ?? [];
    final hasContent = sessions.isNotEmpty || planned.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: hasContent
          ? () {
              if (sessions.isNotEmpty) onSessionTap(sessions.first);
              if (sessions.isEmpty && planned.isNotEmpty) onPlannedTap(planned.first);
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DayNumber(
              day: day,
              isToday: isToday,
              isCurrentMonth: isCurrentMonth,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 2),
            _DotRow(
              sessions: sessions,
              planned: planned,
              onSessionTap: onSessionTap,
              onPlannedTap: onPlannedTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({
    required this.day,
    required this.isToday,
    required this.isCurrentMonth,
    required this.colorScheme,
  });

  final DateTime day;
  final bool isToday;
  final bool isCurrentMonth;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textColor = isCurrentMonth
        ? (isToday ? colorScheme.onPrimary : colorScheme.onSurface)
        : colorScheme.onSurface.withOpacity(0.3);

    return Container(
      width: 28,
      height: 28,
      decoration: isToday
          ? BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            )
          : null,
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          color: textColor,
        ),
      ),
    );
  }
}

class _DotRow extends StatelessWidget {
  const _DotRow({
    required this.sessions,
    required this.planned,
    required this.onSessionTap,
    required this.onPlannedTap,
  });

  final List<SessionResult> sessions;
  final List<PlannedWorkout> planned;
  final void Function(SessionResult) onSessionTap;
  final void Function(PlannedWorkout) onPlannedTap;

  @override
  Widget build(BuildContext context) {
    final dots = <Widget>[];
    var extra = 0;

    for (final s in sessions) {
      if (dots.length >= 3) {
        extra++;
        continue;
      }
      dots.add(GestureDetector(
        onTap: () => onSessionTap(s),
        child: _Dot(color: _rpeColor(s.rpeRating), filled: true),
      ));
    }

    for (final p in planned) {
      if (dots.length >= 3) {
        extra++;
        continue;
      }
      dots.add(GestureDetector(
        onTap: () => onPlannedTap(p),
        child: const _Dot(color: Colors.blueGrey, filled: false),
      ));
    }

    if (extra > 0) {
      dots.add(Text(
        '+$extra',
        style: const TextStyle(fontSize: 9, color: Colors.grey),
      ));
    }

    if (dots.isEmpty) return const SizedBox(height: 8);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: dots.map((d) => Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: d)).toList(),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : null,
        border: filled ? null : Border.all(color: color, width: 1.5),
      ),
    );
  }
}
