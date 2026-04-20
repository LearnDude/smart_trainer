import 'dart:math';
import 'package:flutter/material.dart';
import '../models/flat_step.dart';

class ExecutionChart extends StatelessWidget {
  const ExecutionChart({
    super.key,
    required this.flatSteps,
    required this.powerSamples,
    required this.cursorSeconds,
    required this.ftp,
  });

  final List<FlatStep> flatSteps;
  final List<int> powerSamples;
  final int cursorSeconds;
  final int ftp;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(
        flatSteps: flatSteps,
        powerSamples: powerSamples,
        cursorSeconds: cursorSeconds,
        ftp: ftp,
      ),
      size: Size.infinite,
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({
    required this.flatSteps,
    required this.powerSamples,
    required this.cursorSeconds,
    required this.ftp,
  });

  final List<FlatStep> flatSteps;
  final List<int> powerSamples;
  final int cursorSeconds;
  final int ftp;

  @override
  void paint(Canvas canvas, Size size) {
    final totalSecs = flatSteps.fold(0, (s, step) => s + step.durationSeconds);
    if (totalSecs == 0 || size.width == 0 || size.height == 0) return;

    final maxPlanned =
        flatSteps.fold(0, (m, s) => max(m, max(s.fromWatts, s.toWatts)));
    final maxActual =
        powerSamples.isEmpty ? 0 : powerSamples.reduce(max);
    final yMax =
        max(maxPlanned * 1.15, max(maxActual * 1.15, ftp.toDouble() * 1.1));
    if (yMax == 0) return;

    double xOf(int secs) => secs / totalSecs * size.width;
    double yOf(int watts) => size.height - watts / yMax * size.height;

    // Planned profile — dark grey blocks
    final plannedPaint = Paint()..color = const Color(0xFF37474F);
    double x = 0;
    for (final step in flatSteps) {
      final stepW = step.durationSeconds / totalSecs * size.width;
      if (step.isRamp) {
        final fromH = step.fromWatts / yMax * size.height;
        final toH = step.toWatts / yMax * size.height;
        final path = Path()
          ..moveTo(x, size.height)
          ..lineTo(x, size.height - fromH)
          ..lineTo(x + stepW, size.height - toH)
          ..lineTo(x + stepW, size.height)
          ..close();
        canvas.drawPath(path, plannedPaint);
      } else {
        final blockH = step.fromWatts / yMax * size.height;
        canvas.drawRect(
          Rect.fromLTWH(x, size.height - blockH, stepW, blockH),
          plannedPaint,
        );
      }
      x += stepW;
    }

    // FTP reference line — amber dashed horizontal
    if (ftp > 0) {
      final yFtp = yOf(ftp);
      final ftpPaint = Paint()
        ..color = const Color(0xFFF57F17).withOpacity(0.5)
        ..strokeWidth = 1.0;
      double xPos = 0;
      while (xPos < size.width) {
        canvas.drawLine(
          Offset(xPos, yFtp),
          Offset(min(xPos + 8.0, size.width), yFtp),
          ftpPaint,
        );
        xPos += 16.0;
      }
    }

    // Actual power — bright orange polyline
    if (powerSamples.length >= 2) {
      final linePaint = Paint()
        ..color = const Color(0xFFFF6D00)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(xOf(0), yOf(powerSamples[0]));
      for (int i = 1; i < powerSamples.length; i++) {
        path.lineTo(xOf(i), yOf(powerSamples[i]));
      }
      canvas.drawPath(path, linePaint);
    }

    // Cursor — white dashed vertical line
    if (cursorSeconds > 0 && cursorSeconds <= totalSecs) {
      final cx = xOf(cursorSeconds);
      final cursorPaint = Paint()
        ..color = Colors.white70
        ..strokeWidth = 1.5;
      double yPos = 0;
      while (yPos < size.height) {
        canvas.drawLine(
          Offset(cx, yPos),
          Offset(cx, min(yPos + 6.0, size.height)),
          cursorPaint,
        );
        yPos += 10.0;
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.powerSamples.length != powerSamples.length ||
      old.cursorSeconds != cursorSeconds ||
      old.flatSteps != flatSteps ||
      old.ftp != ftp;
}
