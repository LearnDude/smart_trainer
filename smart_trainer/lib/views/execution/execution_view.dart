import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/trainer_provider.dart';
import '../../widgets/execution_chart.dart';
import '../../widgets/workout_block_chart.dart';

class ExecutionView extends ConsumerWidget {
  const ExecutionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(executionProvider);

    ref.listen<ExecutionState>(executionProvider, (prev, next) {
      if (prev?.status != ExecutionStatus.complete &&
          next.status == ExecutionStatus.complete) {
        ref.read(selectedViewProvider.notifier).state = AppView.postSession;
      }
    });

    return switch (state.status) {
      ExecutionStatus.idle => const _IdleView(),
      ExecutionStatus.active || ExecutionStatus.paused => _ActiveView(state: state),
      ExecutionStatus.complete => const _CompletingView(),
    };
  }
}

// ── Idle ──────────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text('No workout loaded', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Go to Planner to generate and start a workout',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Completing (brief transition while ref.listen fires) ──────────────────────

class _CompletingView extends StatelessWidget {
  const _CompletingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

// ── Active / Paused ───────────────────────────────────────────────────────────

class _ActiveView extends ConsumerWidget {
  const _ActiveView({required this.state});

  final ExecutionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final liveWatts = ref.watch(livePowerProvider).valueOrNull ?? 0;
    final liveHr = ref.watch(liveHeartRateProvider).valueOrNull ?? 0;
    final liveCad = ref.watch(liveCadenceProvider).valueOrNull ?? 0;
    final ftp = ref.watch(settingsProvider).maybeWhen(
          data: (s) => s.ftp,
          orElse: () => 200,
        );
    final isPaused = state.status == ExecutionStatus.paused;

    return Column(
      children: [
        // Title bar + controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state.workout?.name ?? '',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPaused)
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(executionProvider.notifier).resume(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(executionProvider.notifier).pause(),
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _confirmStop(context, ref),
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Live metrics
        _MetricsRow(
          state: state,
          liveWatts: liveWatts,
          liveHr: liveHr,
          liveCad: liveCad,
        ),
        const Divider(height: 1),
        // Power chart
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ExecutionChart(
              flatSteps: state.flatSteps,
              powerSamples: state.powerSamples,
              cursorSeconds: state.totalElapsedSeconds,
              ftp: ftp,
            ),
          ),
        ),
        const Divider(height: 1),
        // Current step progress
        _StepProgress(state: state),
      ],
    );
  }

  Future<void> _confirmStop(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop workout?'),
        content: const Text('Your progress will be saved for review.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(executionProvider.notifier).stop();
    }
  }
}

// ── Metrics row ───────────────────────────────────────────────────────────────

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.state,
    required this.liveWatts,
    required this.liveHr,
    required this.liveCad,
  });

  final ExecutionState state;
  final int liveWatts;
  final int liveHr;
  final int liveCad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Metric(
            'ELAPSED',
            formatDuration(Duration(seconds: state.totalElapsedSeconds)),
          ),
          _Metric(
            'REMAINING',
            formatDuration(Duration(seconds: state.remainingSeconds)),
          ),
          _Metric('TARGET', '${state.targetWatts}W', highlight: true),
          _Metric('POWER', '${liveWatts}W'),
          _Metric('HR', liveHr > 0 ? '$liveHr' : '--'),
          _Metric('CAD', liveCad > 0 ? '$liveCad' : '--'),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, {this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.55),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: highlight ? theme.colorScheme.primary : null,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Step progress ─────────────────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.state});

  final ExecutionState state;

  @override
  Widget build(BuildContext context) {
    final step = state.currentStep;
    if (step == null) return const SizedBox.shrink();

    final progress = step.durationSeconds > 0
        ? (state.stepElapsedSeconds / step.durationSeconds).clamp(0.0, 1.0)
        : 1.0;
    final remaining = Duration(
      seconds: (step.durationSeconds - state.stepElapsedSeconds)
          .clamp(0, step.durationSeconds),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(step.label,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: progress),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            formatDuration(remaining),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
