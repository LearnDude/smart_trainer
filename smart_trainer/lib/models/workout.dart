import 'dart:convert';
import 'package:flutter/foundation.dart';

sealed class PowerTarget {
  const PowerTarget();

  Map<String, dynamic> toJson();

  factory PowerTarget.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'watts' => WattsTarget(json['value'] as int),
      'ftp_percent' => FtpPercentTarget((json['value'] as num).toDouble()),
      _ => throw FormatException('Unknown power type: ${json['type']}'),
    };
  }
}

class WattsTarget extends PowerTarget {
  const WattsTarget(this.watts);
  final int watts;

  @override
  Map<String, dynamic> toJson() => {'type': 'watts', 'value': watts};
}

class FtpPercentTarget extends PowerTarget {
  const FtpPercentTarget(this.percent);
  final double percent;

  int toWatts(int ftp) => (ftp * percent).round();

  @override
  Map<String, dynamic> toJson() => {'type': 'ftp_percent', 'value': percent};
}

sealed class WorkoutStep {
  const WorkoutStep();

  Map<String, dynamic> toJson();

  factory WorkoutStep.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'steady_state' => SteadyState(
          duration: Duration(seconds: json['duration_seconds'] as int),
          power: PowerTarget.fromJson(json['power'] as Map<String, dynamic>),
        ),
      'interval' => IntervalBlock(
          reps: json['reps'] as int,
          on: SteadyState.fromMap(json['on'] as Map<String, dynamic>),
          off: SteadyState.fromMap(json['off'] as Map<String, dynamic>),
        ),
      'ramp' => Ramp(
          duration: Duration(seconds: json['duration_seconds'] as int),
          from: PowerTarget.fromJson(json['from'] as Map<String, dynamic>),
          to: PowerTarget.fromJson(json['to'] as Map<String, dynamic>),
        ),
      _ => throw FormatException('Unknown step type: ${json['type']}'),
    };
  }
}

@immutable
class SteadyState extends WorkoutStep {
  const SteadyState({required this.duration, required this.power});
  final Duration duration;
  final PowerTarget power;

  factory SteadyState.fromMap(Map<String, dynamic> json) => SteadyState(
        duration: Duration(seconds: json['duration_seconds'] as int),
        power: PowerTarget.fromJson(json['power'] as Map<String, dynamic>),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'steady_state',
        'duration_seconds': duration.inSeconds,
        'power': power.toJson(),
      };
}

@immutable
class IntervalBlock extends WorkoutStep {
  const IntervalBlock({required this.reps, required this.on, required this.off});
  final int reps;
  final SteadyState on;
  final SteadyState off;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'interval',
        'reps': reps,
        'on': on.toJson(),
        'off': off.toJson(),
      };
}

@immutable
class Ramp extends WorkoutStep {
  const Ramp({required this.duration, required this.from, required this.to});
  final Duration duration;
  final PowerTarget from;
  final PowerTarget to;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ramp',
        'duration_seconds': duration.inSeconds,
        'from': from.toJson(),
        'to': to.toJson(),
      };
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        name: json['name'] as String,
        steps: (json['steps'] as List)
            .map((s) => WorkoutStep.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  String toJsonString() => jsonEncode(toJson());

  factory Workout.fromJsonString(String s) =>
      Workout.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
