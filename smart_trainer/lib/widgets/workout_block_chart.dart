import 'package:flutter/material.dart';
import '../models/workout.dart';

class WorkoutBlockChart extends StatelessWidget {
  const WorkoutBlockChart({
    super.key,
    required this.workout,
    required this.ftp,
  });

  final Workout workout;
  final int ftp;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BlockPainter(workout: workout, ftp: ftp),
      size: Size.infinite,
    );
  }
}

class _BlockPainter extends CustomPainter {
  const _BlockPainter({required this.workout, required this.ftp});

  final Workout workout;
  final int ftp;

  @override
  void paint(Canvas canvas, Size size) {
    final totalSecs = workout.totalDuration.inSeconds.toDouble();
    if (totalSecs == 0) return;

    double x = 0;

    void drawBlock(int durationSecs, PowerTarget power) {
      final watts = _resolveWatts(power);
      final ratio = ftp > 0 ? watts / ftp : 0.5;
      final blockW = (durationSecs / totalSecs) * size.width;
      final blockH = (ratio.clamp(0.0, 2.0) / 2.0) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(
            x, size.height - blockH, (blockW - 1).clamp(0, blockW), blockH),
        Paint()..color = _zoneColor(ratio),
      );
      x += blockW;
    }

    for (final step in workout.steps) {
      switch (step) {
        case SteadyState s:
          drawBlock(s.duration.inSeconds, s.power);
        case IntervalBlock i:
          for (var r = 0; r < i.reps; r++) {
            drawBlock(i.on.duration.inSeconds, i.on.power);
            drawBlock(i.off.duration.inSeconds, i.off.power);
          }
        case Ramp r:
          final segSecs = r.duration.inSeconds ~/ 20;
          final fromW = _resolveWatts(r.from).toDouble();
          final toW = _resolveWatts(r.to).toDouble();
          for (var j = 0; j < 20; j++) {
            final watts = fromW + (toW - fromW) * (j / 19.0);
            drawBlock(segSecs, WattsTarget(watts.round()));
          }
      }
    }
  }

  int _resolveWatts(PowerTarget power) => switch (power) {
        WattsTarget w => w.watts,
        FtpPercentTarget f => f.toWatts(ftp),
      };

  Color _zoneColor(double ratio) {
    if (ratio < 0.55) return const Color(0xFF546E7A);
    if (ratio < 0.75) return const Color(0xFF1565C0);
    if (ratio < 0.90) return const Color(0xFF2E7D32);
    if (ratio < 1.05) return const Color(0xFFF57F17);
    if (ratio < 1.20) return const Color(0xFFE65100);
    if (ratio < 1.50) return const Color(0xFFB71C1C);
    return const Color(0xFF4A148C);
  }

  @override
  bool shouldRepaint(_BlockPainter old) =>
      old.workout != workout || old.ftp != ftp;
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String describePower(PowerTarget power, int ftp) => switch (power) {
      WattsTarget w => '${w.watts}W',
      FtpPercentTarget f =>
        '${(f.percent * 100).round()}% FTP (~${f.toWatts(ftp)}W)',
    };
