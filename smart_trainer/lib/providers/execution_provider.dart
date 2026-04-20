import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flat_step.dart';
import '../models/workout.dart';
import 'trainer_provider.dart';

enum ExecutionStatus { idle, active, paused, complete }

class ExecutionState {
  const ExecutionState({
    this.status = ExecutionStatus.idle,
    this.workout,
    this.flatSteps = const [],
    this.currentStepIndex = 0,
    this.stepElapsedSeconds = 0,
    this.totalElapsedSeconds = 0,
    this.targetWatts = 0,
    this.powerSamples = const [],
    this.hrSamples = const [],
  });

  final ExecutionStatus status;
  final Workout? workout;
  final List<FlatStep> flatSteps;
  final int currentStepIndex;
  final int stepElapsedSeconds;
  final int totalElapsedSeconds;
  final int targetWatts;
  final List<int> powerSamples;
  final List<int> hrSamples;

  int get totalDurationSeconds =>
      flatSteps.fold(0, (s, step) => s + step.durationSeconds);

  int get remainingSeconds =>
      (totalDurationSeconds - totalElapsedSeconds).clamp(0, totalDurationSeconds);

  FlatStep? get currentStep =>
      flatSteps.isNotEmpty && currentStepIndex < flatSteps.length
          ? flatSteps[currentStepIndex]
          : null;

  int get avgPower {
    final valid = powerSamples.where((p) => p > 0).toList();
    if (valid.isEmpty) return 0;
    return valid.reduce((a, b) => a + b) ~/ valid.length;
  }

  int get avgHr {
    final valid = hrSamples.where((h) => h > 0).toList();
    if (valid.isEmpty) return 0;
    return valid.reduce((a, b) => a + b) ~/ valid.length;
  }

  ExecutionState copyWith({
    ExecutionStatus? status,
    Workout? workout,
    List<FlatStep>? flatSteps,
    int? currentStepIndex,
    int? stepElapsedSeconds,
    int? totalElapsedSeconds,
    int? targetWatts,
    List<int>? powerSamples,
    List<int>? hrSamples,
  }) =>
      ExecutionState(
        status: status ?? this.status,
        workout: workout ?? this.workout,
        flatSteps: flatSteps ?? this.flatSteps,
        currentStepIndex: currentStepIndex ?? this.currentStepIndex,
        stepElapsedSeconds: stepElapsedSeconds ?? this.stepElapsedSeconds,
        totalElapsedSeconds: totalElapsedSeconds ?? this.totalElapsedSeconds,
        targetWatts: targetWatts ?? this.targetWatts,
        powerSamples: powerSamples ?? this.powerSamples,
        hrSamples: hrSamples ?? this.hrSamples,
      );
}

class ExecutionNotifier extends Notifier<ExecutionState> {
  Timer? _timer;

  @override
  ExecutionState build() {
    ref.onDispose(() => _timer?.cancel());
    return const ExecutionState();
  }

  Future<void> startWorkout(Workout workout, int ftp) async {
    _timer?.cancel();
    final flat = flattenWorkout(workout, ftp);
    if (flat.isEmpty) return;
    final firstWatts = flat.first.wattsAt(0);
    await _sendErg(firstWatts);
    state = ExecutionState(
      status: ExecutionStatus.active,
      workout: workout,
      flatSteps: flat,
      targetWatts: firstWatts,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    if (state.status != ExecutionStatus.active) return;
    _timer?.cancel();
    _sendErg(50);
    state = state.copyWith(status: ExecutionStatus.paused);
  }

  void resume() {
    if (state.status != ExecutionStatus.paused) return;
    _sendErg(state.targetWatts);
    state = state.copyWith(status: ExecutionStatus.active);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> stop() async {
    _timer?.cancel();
    await _sendErg(50);
    state = state.copyWith(status: ExecutionStatus.complete);
  }

  void reset() {
    _timer?.cancel();
    state = const ExecutionState();
  }

  void _tick() {
    if (state.status != ExecutionStatus.active) return;
    final current = state.currentStep;
    if (current == null) {
      _timer?.cancel();
      state = state.copyWith(status: ExecutionStatus.complete);
      return;
    }

    final newTotal = state.totalElapsedSeconds + 1;
    final newStepElapsed = state.stepElapsedSeconds + 1;
    final power = ref.read(livePowerProvider).valueOrNull ?? 0;
    final hr = ref.read(liveHeartRateProvider).valueOrNull ?? 0;
    final newPower = [...state.powerSamples, power];
    final newHr = [...state.hrSamples, hr];

    if (newStepElapsed >= current.durationSeconds) {
      final nextIndex = state.currentStepIndex + 1;
      if (nextIndex >= state.flatSteps.length) {
        _timer?.cancel();
        state = state.copyWith(
          status: ExecutionStatus.complete,
          totalElapsedSeconds: newTotal,
          powerSamples: newPower,
          hrSamples: newHr,
        );
        return;
      }
      final nextStep = state.flatSteps[nextIndex];
      final nextWatts = nextStep.wattsAt(0);
      _sendErg(nextWatts);
      state = state.copyWith(
        currentStepIndex: nextIndex,
        stepElapsedSeconds: 0,
        totalElapsedSeconds: newTotal,
        targetWatts: nextWatts,
        powerSamples: newPower,
        hrSamples: newHr,
      );
    } else {
      final watts = current.wattsAt(newStepElapsed);
      if (current.isRamp) _sendErg(watts);
      state = state.copyWith(
        stepElapsedSeconds: newStepElapsed,
        totalElapsedSeconds: newTotal,
        targetWatts: watts,
        powerSamples: newPower,
        hrSamples: newHr,
      );
    }
  }

  Future<void> _sendErg(int watts) =>
      ref.read(trainerServiceProvider).setTargetPower(watts);
}

final executionProvider =
    NotifierProvider<ExecutionNotifier, ExecutionState>(ExecutionNotifier.new);
