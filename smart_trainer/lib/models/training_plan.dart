import 'workout.dart';

class PlannedEntry {
  const PlannedEntry({required this.date, required this.workout});
  final DateTime date;
  final Workout workout;
}

class TrainingPlan {
  const TrainingPlan({required this.name, required this.entries});
  final String name;
  final List<PlannedEntry> entries;

  Map<int, List<PlannedEntry>> get byWeekNumber {
    if (entries.isEmpty) return {};
    final firstDate = entries.first.date;
    final map = <int, List<PlannedEntry>>{};
    for (final entry in entries) {
      final weekNum = (entry.date.difference(firstDate).inDays ~/ 7) + 1;
      (map[weekNum] ??= []).add(entry);
    }
    return map;
  }
}
