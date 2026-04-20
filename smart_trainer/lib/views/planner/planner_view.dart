import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/training_plan.dart';
import '../../models/workout.dart';
import '../../providers/execution_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/planner_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/trainer_provider.dart';
import '../../widgets/workout_block_chart.dart';
import '../editor/editor_view.dart';

class PlannerView extends ConsumerStatefulWidget {
  const PlannerView({super.key});

  @override
  ConsumerState<PlannerView> createState() => _PlannerViewState();
}

class _PlannerViewState extends ConsumerState<PlannerView> {
  final _promptCtrl = TextEditingController();

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;
    await ref.read(plannerProvider.notifier).generate(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(plannerProvider);
    final ftp = ref
        .watch(settingsProvider)
        .maybeWhen(data: (s) => s.ftp, orElse: () => 200);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 340,
          child: _InputPanel(
            ctrl: _promptCtrl,
            mode: state.mode,
            isLoading: state.isLoading,
            error: state.error,
            onModeChanged: (m) => ref.read(plannerProvider.notifier).setMode(m),
            onGenerate: _generate,
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: state.workout != null
              ? _WorkoutPreviewPanel(workout: state.workout!, ftp: ftp)
              : state.plan != null
                  ? _PlanPreviewPanel(plan: state.plan!, ftp: ftp)
                  : const _EmptyPreview(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Input panel
// ---------------------------------------------------------------------------

class _InputPanel extends StatelessWidget {
  const _InputPanel({
    required this.ctrl,
    required this.mode,
    required this.isLoading,
    required this.error,
    required this.onModeChanged,
    required this.onGenerate,
  });

  final TextEditingController ctrl;
  final PlannerMode mode;
  final bool isLoading;
  final String? error;
  final ValueChanged<PlannerMode> onModeChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Workout Planner', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<PlannerMode>(
            segments: const [
              ButtonSegment(
                value: PlannerMode.singleWorkout,
                label: Text('Single Workout'),
                icon: Icon(Icons.fitness_center),
              ),
              ButtonSegment(
                value: PlannerMode.trainingPlan,
                label: Text('Training Plan'),
                icon: Icon(Icons.calendar_today),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) => onModeChanged(s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            maxLines: 6,
            minLines: 3,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: mode == PlannerMode.singleWorkout
                  ? 'Describe the workout you want…\ne.g. "60 min threshold with 3x10 at FTP"'
                  : 'Describe your training goal…\ne.g. "4-week aerobic base building, 4 days per week"',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isLoading ? null : onGenerate,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(isLoading ? 'Generating…' : 'Generate'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty preview
// ---------------------------------------------------------------------------

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(80)),
          const SizedBox(height: 12),
          Text(
            'Describe your workout and tap Generate',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Workout preview
// ---------------------------------------------------------------------------

class _WorkoutPreviewPanel extends ConsumerWidget {
  const _WorkoutPreviewPanel({required this.workout, required this.ftp});

  final Workout workout;
  final int ftp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final total = workout.totalDuration;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(workout.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          formatDuration(total),
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 72,
            child: WorkoutBlockChart(workout: workout, ftp: ftp),
          ),
        ),
        const SizedBox(height: 20),
        Text('Steps', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._buildStepTiles(context, workout.steps, ftp),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditorView(initialWorkout: workout),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(plannerProvider.notifier).saveToLibrary(workout);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saved to Library')),
                  );
                }
              },
              icon: const Icon(Icons.bookmark_outline),
              label: const Text('Save to Library'),
            ),
            OutlinedButton.icon(
              onPressed: () => _startWorkout(context, ref, workout, ftp),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Start'),
            ),
            FilledButton.icon(
              onPressed: () => _pickDateAndSchedule(context, ref, workout),
              icon: const Icon(Icons.event),
              label: const Text('Schedule'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _startWorkout(
      BuildContext context, WidgetRef ref, Workout workout, int ftp) async {
    final conn = ref.read(trainerConnectionProvider).valueOrNull;
    if (conn != BluetoothConnectionState.connected) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trainer not connected — pair it in Setup first'),
        ),
      );
      return;
    }
    await ref.read(executionProvider.notifier).startWorkout(workout, ftp);
    if (!context.mounted) return;
    ref.read(selectedViewProvider.notifier).state = AppView.execution;
  }

  Future<void> _pickDateAndSchedule(
      BuildContext context, WidgetRef ref, Workout workout) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !context.mounted) return;
    await ref.read(plannerProvider.notifier).scheduleWorkout(workout, picked);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Scheduled "${workout.name}" for ${_formatDate(picked)}'),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Training plan preview
// ---------------------------------------------------------------------------

class _PlanPreviewPanel extends ConsumerWidget {
  const _PlanPreviewPanel({required this.plan, required this.ftp});

  final TrainingPlan plan;
  final int ftp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final weeks = plan.byWeekNumber;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(plan.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '${plan.entries.length} workouts · ${weeks.length} weeks',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 20),
        for (final entry in weeks.entries) ...[
          _WeekTile(weekNum: entry.key, workouts: entry.value, ftp: ftp),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _scheduleAll(context, ref),
              icon: const Icon(Icons.event_available),
              label: const Text('Schedule All'),
            ),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Save Plan coming in Phase 7')),
              ),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Plan'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _scheduleAll(BuildContext context, WidgetRef ref) async {
    await ref.read(plannerProvider.notifier).scheduleAll(plan);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${plan.entries.length} workouts scheduled to Calendar'),
        ),
      );
    }
  }
}

class _WeekTile extends StatelessWidget {
  const _WeekTile(
      {required this.weekNum, required this.workouts, required this.ftp});

  final int weekNum;
  final List<PlannedEntry> workouts;
  final int ftp;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text('Week $weekNum'),
        subtitle: Text('${workouts.length} workouts'),
        children: [
          for (final entry in workouts)
            ListTile(
              leading: SizedBox(
                width: 80,
                height: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: WorkoutBlockChart(workout: entry.workout, ftp: ftp),
                ),
              ),
              title: Text(entry.workout.name),
              subtitle: Text(
                '${_weekdayName(entry.date.weekday)} ${_formatDate(entry.date)} · ${formatDuration(entry.workout.totalDuration)}',
              ),
            ),
        ],
      ),
    );
  }

  String _weekdayName(int weekday) => const [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun'
      ][weekday - 1];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<Widget> _buildStepTiles(
    BuildContext context, List<WorkoutStep> steps, int ftp) {
  return steps.map((step) {
    return switch (step) {
      SteadyState s => ListTile(
          dense: true,
          leading: const Icon(Icons.remove, size: 16),
          title: Text(formatDuration(s.duration)),
          subtitle: Text(describePower(s.power, ftp)),
        ),
      IntervalBlock i => ListTile(
          dense: true,
          leading: const Icon(Icons.repeat, size: 16),
          title: Text('${i.reps}× intervals'),
          subtitle: Text(
            '${formatDuration(i.on.duration)} @ ${describePower(i.on.power, ftp)}'
            '  /  ${formatDuration(i.off.duration)} @ ${describePower(i.off.power, ftp)}',
          ),
        ),
      Ramp r => ListTile(
          dense: true,
          leading: const Icon(Icons.trending_up, size: 16),
          title: Text('Ramp ${formatDuration(r.duration)}'),
          subtitle: Text(
              '${describePower(r.from, ftp)} → ${describePower(r.to, ftp)}'),
        ),
    };
  }).toList();
}

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
