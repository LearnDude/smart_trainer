import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/planned_workout.dart';
import '../../../models/workout.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/planned_workouts_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/execution_provider.dart';

void showPlannedDetailSheet(BuildContext context, PlannedWorkout pw) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _PlannedDetailSheet(pw: pw),
  );
}

class _PlannedDetailSheet extends ConsumerWidget {
  const _PlannedDetailSheet({required this.pw});

  final PlannedWorkout pw;

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    return '${m}min';
  }

  String _intensitySummary(Workout w) {
    final steps = w.steps;
    if (steps.isEmpty) return '';
    final intervals = steps.whereType<IntervalBlock>().toList();
    if (intervals.isNotEmpty) {
      final b = intervals.first;
      return '${b.reps}x interval block';
    }
    return '${steps.length} steps · ${_fmtDuration(w.totalDuration)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = pw.date;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final workout = pw.workout;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(pw.name, style: Theme.of(context).textTheme.titleLarge),
          Text(dateStr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(_intensitySummary(workout)),
          Text('Duration: ${_fmtDuration(workout.totalDuration)}'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Now'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final settings = await ref.read(settingsProvider.future);
                    ref.read(executionProvider.notifier).startWorkout(workout, settings.ftp);
                    ref.read(selectedViewProvider.notifier).state = AppView.execution;
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (pw.id != null) {
                    ref.read(plannedWorkoutsProvider.notifier).delete(pw.id!);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
