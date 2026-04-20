import 'dart:convert';

class SessionResult {
  const SessionResult({
    this.id,
    required this.date,
    required this.workoutName,
    required this.durationSeconds,
    required this.avgPower,
    required this.avgHr,
    required this.tss,
    required this.powerSamples,
    required this.hrSamples,
    required this.workoutJson,
    required this.rpeRating,
    this.notes = '',
  });

  final int? id;
  final DateTime date;
  final String workoutName;
  final int durationSeconds;
  final int avgPower;
  final int avgHr;
  final double tss;
  final List<int> powerSamples;
  final List<int> hrSamples;
  final String workoutJson;
  final int rpeRating; // 1–5 (Easy → Maximum Effort)
  final String notes;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date.toIso8601String(),
        'workout_name': workoutName,
        'duration_sec': durationSeconds,
        'avg_power': avgPower,
        'avg_hr': avgHr,
        'tss': tss,
        'power_samples': jsonEncode(powerSamples),
        'hr_samples': jsonEncode(hrSamples),
        'workout_json': workoutJson,
        'rpe_rating': rpeRating,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      };

  factory SessionResult.fromMap(Map<String, dynamic> m) => SessionResult(
        id: m['id'] as int?,
        date: DateTime.parse(m['date'] as String),
        workoutName: m['workout_name'] as String,
        durationSeconds: m['duration_sec'] as int,
        avgPower: m['avg_power'] as int,
        avgHr: m['avg_hr'] as int,
        tss: (m['tss'] as num).toDouble(),
        powerSamples:
            (jsonDecode(m['power_samples'] as String) as List).cast<int>(),
        hrSamples:
            (jsonDecode(m['hr_samples'] as String) as List).cast<int>(),
        workoutJson: m['workout_json'] as String,
        rpeRating: m['rpe_rating'] as int,
        notes: m['notes'] as String? ?? '',
      );
}
