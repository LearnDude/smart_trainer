import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/planned_workout.dart';
import '../models/session_result.dart';
import 'planned_workouts_provider.dart';
import 'session_history_provider.dart';

@immutable
class CalendarDay {
  const CalendarDay({
    required this.date,
    this.sessions = const [],
    this.planned = const [],
  });

  final DateTime date;
  final List<SessionResult> sessions;
  final List<PlannedWorkout> planned;
}

final calendarDayMapProvider = Provider<Map<String, CalendarDay>>((ref) {
  final sessionsAsync = ref.watch(sessionHistoryProvider);
  final plannedAsync = ref.watch(plannedWorkoutsProvider);

  final sessions = sessionsAsync.valueOrNull ?? [];
  final planned = plannedAsync.valueOrNull ?? [];

  final map = <String, CalendarDay>{};

  for (final s in sessions) {
    final key = s.date.toIso8601String().substring(0, 10);
    final existing = map[key];
    map[key] = CalendarDay(
      date: s.date,
      sessions: [...(existing?.sessions ?? []), s],
      planned: existing?.planned ?? [],
    );
  }

  for (final p in planned) {
    final key = p.date.toIso8601String().substring(0, 10);
    final existing = map[key];
    map[key] = CalendarDay(
      date: p.date,
      sessions: existing?.sessions ?? [],
      planned: [...(existing?.planned ?? []), p],
    );
  }

  return map;
});
