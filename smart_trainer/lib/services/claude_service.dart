import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/training_plan.dart';
import '../models/user_settings.dart';
import '../models/workout.dart';

class ClaudeService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';
  static const _anthropicVersion = '2023-06-01';

  final _dio = Dio();

  Future<Workout> generateWorkout({
    required String apiKey,
    required String prompt,
    required UserSettings settings,
  }) async {
    final text = await _call(
      apiKey: apiKey,
      system: _singleWorkoutPrompt(settings),
      message: prompt,
      maxTokens: 2048,
    );
    return Workout.fromJson(_extractJson(text));
  }

  /// Returns the generated Workout and the resolved scheduled date.
  Future<(Workout, DateTime)> generateScheduledWorkout({
    required String apiKey,
    required String prompt,
    required UserSettings settings,
    required DateTime today,
  }) async {
    final text = await _call(
      apiKey: apiKey,
      system: _scheduledWorkoutPrompt(settings, today),
      message: prompt,
      maxTokens: 2048,
    );
    final json = _extractJson(text);
    final workout = Workout.fromJson(json);
    final dateStr = json['scheduled_date'] as String?;
    final date = dateStr != null ? DateTime.parse(dateStr) : today;
    return (workout, date);
  }

  Future<TrainingPlan> generateTrainingPlan({
    required String apiKey,
    required String prompt,
    required UserSettings settings,
    required DateTime today,
  }) async {
    final text = await _call(
      apiKey: apiKey,
      system: _trainingPlanPrompt(settings, today),
      message: prompt,
      maxTokens: 8192,
    );
    return _parseTrainingPlan(_extractJson(text));
  }

  Future<String> _call({
    required String apiKey,
    required String system,
    required String message,
    required int maxTokens,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint,
      options: Options(headers: {
        'x-api-key': apiKey,
        'anthropic-version': _anthropicVersion,
        'content-type': 'application/json',
      }),
      data: {
        'model': _model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': message},
        ],
      },
    );
    final content =
        (response.data!['content'] as List).first as Map<String, dynamic>;
    return content['text'] as String;
  }

  Map<String, dynamic> _extractJson(String text) {
    final stripped = text.trim();
    final match =
        RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(stripped);
    final raw = match?.group(1) ?? stripped;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  TrainingPlan _parseTrainingPlan(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Training Plan';
    final weeks = json['weeks'] as List;
    final entries = <PlannedEntry>[];
    for (final week in weeks) {
      final workouts = (week as Map<String, dynamic>)['workouts'] as List;
      for (final w in workouts) {
        final wMap = w as Map<String, dynamic>;
        entries.add(PlannedEntry(
          date: DateTime.parse(wMap['date'] as String),
          workout: Workout.fromJson(wMap),
        ));
      }
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    return TrainingPlan(name: name, entries: entries);
  }

  String _singleWorkoutPrompt(UserSettings s) => '''
You are a cycling coach. Generate a structured indoor cycling workout as JSON.

Athlete profile: FTP ${s.ftp}W${s.vt1 > 0 ? ', VT1 ${s.vt1}W' : ''}${s.vt2 > 0 ? ', VT2 ${s.vt2}W' : ''}${s.maxHr > 0 ? ', Max HR ${s.maxHr}bpm' : ''}.

Return ONLY a valid JSON object — no explanation, no markdown, no code fences:

{"name":"string","steps":[
  {"type":"steady_state","duration_seconds":integer,"power":{"type":"watts","value":integer}},
  {"type":"interval","reps":integer,"on":<steady_state>,"off":<steady_state>},
  {"type":"ramp","duration_seconds":integer,"from":<power>,"to":<power>}
]}

Power type is "watts" (absolute) or "ftp_percent" (0.0–2.0 range). Always include warmup and cooldown.''';

  String _scheduledWorkoutPrompt(UserSettings s, DateTime today) => '''
You are a cycling coach. Generate a structured indoor cycling workout as JSON, then schedule it.

Athlete profile: FTP ${s.ftp}W${s.vt1 > 0 ? ', VT1 ${s.vt1}W' : ''}${s.vt2 > 0 ? ', VT2 ${s.vt2}W' : ''}${s.maxHr > 0 ? ', Max HR ${s.maxHr}bpm' : ''}. Today: ${today.toIso8601String().substring(0, 10)}.

If the user mentions a date (e.g. "Thursday", "next Monday", "in 3 days"), resolve it to an absolute ISO date and include "scheduled_date": "YYYY-MM-DD". If no date is mentioned, use today.

Return ONLY a valid JSON object — no explanation, no markdown, no code fences:

{"scheduled_date":"YYYY-MM-DD","name":"string","steps":[
  {"type":"steady_state","duration_seconds":integer,"power":{"type":"watts","value":integer}},
  {"type":"interval","reps":integer,"on":<steady_state>,"off":<steady_state>},
  {"type":"ramp","duration_seconds":integer,"from":<power>,"to":<power>}
]}

Power type is "watts" (absolute) or "ftp_percent" (0.0–2.0 range). Always include warmup and cooldown.''';

  String _trainingPlanPrompt(UserSettings s, DateTime today) => '''
You are a cycling coach. Generate a multi-week training plan as JSON.

Athlete profile: FTP ${s.ftp}W${s.vt1 > 0 ? ', VT1 ${s.vt1}W' : ''}${s.vt2 > 0 ? ', VT2 ${s.vt2}W' : ''}${s.maxHr > 0 ? ', Max HR ${s.maxHr}bpm' : ''}. Today: ${today.toIso8601String().substring(0, 10)}.

Return ONLY a valid JSON object:

{"name":"string","weeks":[{"week_number":integer,"focus":"string","workouts":[{"date":"YYYY-MM-DD","name":"string","steps":[<same step schema>]}]}]}

Apply progressive overload. Omit rest days. Each workout must have warmup and cooldown.''';
}

final claudeServiceProvider = Provider((_) => ClaudeService());
