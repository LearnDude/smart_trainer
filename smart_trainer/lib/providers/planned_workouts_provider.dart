import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/planned_workout.dart';
import '../services/database_service.dart';

class PlannedWorkoutsNotifier extends AsyncNotifier<List<PlannedWorkout>> {
  @override
  Future<List<PlannedWorkout>> build() =>
      ref.read(databaseServiceProvider).queryAllPlannedWorkouts();

  Future<void> add(PlannedWorkout pw) async {
    await ref.read(databaseServiceProvider).insertPlannedWorkoutModel(pw);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await ref.read(databaseServiceProvider).deletePlannedWorkout(id);
    ref.invalidateSelf();
  }
}

final plannedWorkoutsProvider =
    AsyncNotifierProvider<PlannedWorkoutsNotifier, List<PlannedWorkout>>(
        PlannedWorkoutsNotifier.new);
