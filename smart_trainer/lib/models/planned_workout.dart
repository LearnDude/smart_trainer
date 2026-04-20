import 'package:flutter/foundation.dart';
import 'workout.dart';

@immutable
class PlannedWorkout {
  const PlannedWorkout({
    this.id,
    required this.date,
    required this.name,
    required this.workoutJson,
  });

  final int? id;
  final DateTime date;
  final String name;
  final String workoutJson;

  Workout get workout => Workout.fromJsonString(workoutJson);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date.toIso8601String().substring(0, 10),
        'name': name,
        'workout_json': workoutJson,
      };

  factory PlannedWorkout.fromMap(Map<String, dynamic> m) => PlannedWorkout(
        id: m['id'] as int?,
        date: DateTime.parse(m['date'] as String),
        name: m['name'] as String,
        workoutJson: m['workout_json'] as String,
      );
}
