import 'package:flutter/foundation.dart';

sealed class PowerTarget {
  const PowerTarget();
}

class WattsTarget extends PowerTarget {
  const WattsTarget(this.watts);
  final int watts;
}

class FtpPercentTarget extends PowerTarget {
  const FtpPercentTarget(this.percent);
  final double percent;

  int toWatts(int ftp) => (ftp * percent).round();
}

sealed class WorkoutStep {
  const WorkoutStep();
}

@immutable
class SteadyState extends WorkoutStep {
  const SteadyState({required this.duration, required this.power});
  final Duration duration;
  final PowerTarget power;
}

@immutable
class IntervalBlock extends WorkoutStep {
  const IntervalBlock({required this.reps, required this.on, required this.off});
  final int reps;
  final SteadyState on;
  final SteadyState off;
}

@immutable
class Ramp extends WorkoutStep {
  const Ramp({required this.duration, required this.from, required this.to});
  final Duration duration;
  final PowerTarget from;
  final PowerTarget to;
}

@immutable
class Workout {
  const Workout({required this.name, required this.steps});
  final String name;
  final List<WorkoutStep> steps;

  Duration get totalDuration {
    Duration total = Duration.zero;
    for (final step in steps) {
      switch (step) {
        case SteadyState s:
          total += s.duration;
        case IntervalBlock i:
          total += (i.on.duration + i.off.duration) * i.reps;
        case Ramp r:
          total += r.duration;
      }
    }
    return total;
  }
}
