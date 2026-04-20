import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/planned_workout.dart';
import '../../../providers/planned_workouts_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/api_key_service.dart';
import '../../../services/claude_service.dart';


class NlpScheduleBar extends ConsumerStatefulWidget {
  const NlpScheduleBar({super.key});

  @override
  ConsumerState<NlpScheduleBar> createState() => _NlpScheduleBarState();
}

class _NlpScheduleBarState extends ConsumerState<NlpScheduleBar> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;
    setState(() => _loading = true);
    try {
      final apiKey = await ref.read(apiKeyServiceProvider).getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Set your Claude API key in Setup')),
          );
        }
        return;
      }
      final settings = await ref.read(settingsProvider.future);
      final (workout, date) = await ref.read(claudeServiceProvider).generateScheduledWorkout(
            apiKey: apiKey,
            prompt: prompt,
            settings: settings,
            today: DateTime.now(),
          );
      await ref.read(plannedWorkoutsProvider.notifier).add(PlannedWorkout(
            date: date,
            name: workout.name,
            workoutJson: workout.toJsonString(),
          ));
      if (mounted) {
        _controller.clear();
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workout scheduled for $dateStr')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Schedule a workout… e.g. "Easy 45 min zone 2 on Thursday"',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _generate(),
              enabled: !_loading,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _loading ? null : _generate,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Generate'),
          ),
        ],
      ),
    );
  }
}
