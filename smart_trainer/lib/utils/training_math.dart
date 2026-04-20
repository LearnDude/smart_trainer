import 'dart:math';

/// Normalized Power from a list of 1-second power samples.
/// Uses a 30-second rolling average, then the 4th-power mean.
double computeNP(List<int> powerSamples) {
  if (powerSamples.isEmpty) return 0;
  const windowSize = 30;
  var rollingSum = 0.0;
  var fourthPowerSum = 0.0;
  final windowBuffer = List<int>.filled(windowSize, 0);
  var count = 0;

  for (int i = 0; i < powerSamples.length; i++) {
    final slot = i % windowSize;
    rollingSum -= windowBuffer[slot];
    windowBuffer[slot] = powerSamples[i];
    rollingSum += powerSamples[i];
    count = count < windowSize ? count + 1 : windowSize;
    final avg = rollingSum / count;
    fourthPowerSum += avg * avg * avg * avg;
  }

  final meanFourthPower = fourthPowerSum / powerSamples.length;
  return pow(meanFourthPower, 0.25).toDouble();
}

/// Training Stress Score.
/// TSS = (duration_hours) × IF² × 100, where IF = NP / FTP.
double computeTSS(int durationSeconds, double np, int ftp) {
  if (ftp <= 0 || durationSeconds <= 0) return 0;
  final intensityFactor = np / ftp;
  return (durationSeconds / 3600) * intensityFactor * intensityFactor * 100;
}
