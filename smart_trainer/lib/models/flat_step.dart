import 'workout.dart';

class FlatStep {
  const FlatStep._({
    required this.label,
    required this.durationSeconds,
    required this.fromWatts,
    required this.toWatts,
    required this.isRamp,
  });

  factory FlatStep.steady({
    required String label,
    required int durationSeconds,
    required int watts,
  }) =>
      FlatStep._(
        label: label,
        durationSeconds: durationSeconds,
        fromWatts: watts,
        toWatts: watts,
        isRamp: false,
      );

  factory FlatStep.ramp({
    required String label,
    required int durationSeconds,
    required int fromWatts,
    required int toWatts,
  }) =>
      FlatStep._(
        label: label,
        durationSeconds: durationSeconds,
        fromWatts: fromWatts,
        toWatts: toWatts,
        isRamp: true,
      );

  final String label;
  final int durationSeconds;
  final int fromWatts;
  final int toWatts;
  final bool isRamp;

  int wattsAt(int stepElapsedSeconds) {
    if (!isRamp || durationSeconds <= 0) return fromWatts;
    final t = (stepElapsedSeconds / durationSeconds).clamp(0.0, 1.0);
    return (fromWatts + (toWatts - fromWatts) * t).round();
  }
}

List<FlatStep> flattenWorkout(Workout workout, int ftp) {
  final steps = <FlatStep>[];
  final total = workout.steps.length;
  for (int i = 0; i < total; i++) {
    final step = workout.steps[i];
    switch (step) {
      case SteadyState s:
        steps.add(FlatStep.steady(
          label: _steadyLabel(i, total),
          durationSeconds: s.duration.inSeconds,
          watts: _resolveWatts(s.power, ftp),
        ));
      case IntervalBlock ib:
        final onW = _resolveWatts(ib.on.power, ftp);
        final offW = _resolveWatts(ib.off.power, ftp);
        for (int rep = 0; rep < ib.reps; rep++) {
          steps.add(FlatStep.steady(
            label: 'Interval ${rep + 1}/${ib.reps} \u00b7 ON',
            durationSeconds: ib.on.duration.inSeconds,
            watts: onW,
          ));
          steps.add(FlatStep.steady(
            label: 'Interval ${rep + 1}/${ib.reps} \u00b7 OFF',
            durationSeconds: ib.off.duration.inSeconds,
            watts: offW,
          ));
        }
      case Ramp r:
        steps.add(FlatStep.ramp(
          label: 'Ramp',
          durationSeconds: r.duration.inSeconds,
          fromWatts: _resolveWatts(r.from, ftp),
          toWatts: _resolveWatts(r.to, ftp),
        ));
    }
  }
  return steps;
}

int _resolveWatts(PowerTarget power, int ftp) => switch (power) {
      WattsTarget w => w.watts,
      FtpPercentTarget f => f.toWatts(ftp),
    };

String _steadyLabel(int index, int total) {
  if (total == 1) return 'Main Set';
  if (index == 0) return 'Warm-up';
  if (index == total - 1) return 'Cool-down';
  return 'Step ${index + 1}';
}
