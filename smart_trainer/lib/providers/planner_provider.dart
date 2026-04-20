import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/training_plan.dart';
import '../models/workout.dart';
import '../services/api_key_service.dart';
import '../services/claude_service.dart';
import '../services/database_service.dart';
import 'settings_provider.dart';

enum PlannerMode { singleWorkout, trainingPlan }

class PlannerState {
  const PlannerState({
    this.mode = PlannerMode.singleWorkout,
    this.isLoading = false,
    this.workout,
    this.plan,
    this.error,
  });

  final PlannerMode mode;
  final bool isLoading;
  final Workout? workout;
  final TrainingPlan? plan;
  final String? error;

  PlannerState copyWith({
    PlannerMode? mode,
    bool? isLoading,
    Workout? workout,
    TrainingPlan? plan,
    String? error,
    bool clearWorkout = false,
    bool clearPlan = false,
    bool clearError = false,
  }) =>
      PlannerState(
        mode: mode ?? this.mode,
        isLoading: isLoading ?? this.isLoading,
        workout: clearWorkout ? null : (workout ?? this.workout),
        plan: clearPlan ? null : (plan ?? this.plan),
        error: clearError ? null : (error ?? this.error),
      );
}

class PlannerNotifier extends Notifier<PlannerState> {
  @override
  PlannerState build() => const PlannerState();

  void setMode(PlannerMode mode) => state = PlannerState(mode: mode);

  Future<void> generate(String prompt) async {
    final apiKey = await ref.read(apiKeyServiceProvider).getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      state = state.copyWith(error: 'Claude API key not set — add it in Setup');
      return;
    }

    final settings = await ref.read(settingsProvider.future);
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearWorkout: true,
      clearPlan: true,
    );

    try {
      final claude = ref.read(claudeServiceProvider);
      if (state.mode == PlannerMode.singleWorkout) {
        final workout = await claude.generateWorkout(
          apiKey: apiKey,
          prompt: prompt,
          settings: settings,
        );
        state = state.copyWith(isLoading: false, workout: workout);
      } else {
        final plan = await claude.generateTrainingPlan(
          apiKey: apiKey,
          prompt: prompt,
          settings: settings,
          today: DateTime.now(),
        );
        state = state.copyWith(isLoading: false, plan: plan);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  Future<void> scheduleWorkout(Workout workout, DateTime date) async =>
      ref.read(databaseServiceProvider).insertPlannedWorkout(date, workout);

  Future<void> scheduleAll(TrainingPlan plan) async {
    final db = ref.read(databaseServiceProvider);
    for (final entry in plan.entries) {
      await db.insertPlannedWorkout(entry.date, entry.workout);
    }
  }

  Future<void> saveToLibrary(Workout workout) async =>
      ref.read(databaseServiceProvider).insertLibraryWorkout(workout);

  String _friendlyError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 401) return 'Invalid API key — check Setup';
      if (status == 429) return 'Rate limited — wait a moment and try again';
      return 'API error ($status): ${e.message}';
    }
    return e.toString();
  }
}

final plannerProvider =
    NotifierProvider<PlannerNotifier, PlannerState>(PlannerNotifier.new);
