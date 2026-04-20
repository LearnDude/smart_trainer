import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/session_result.dart';
import '../../providers/execution_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/session_history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/strava_service.dart';
import '../../utils/training_math.dart';

const _rpeOptions = [
  (1, 'Easy', 'Non-taxing, little effort. Could repeat it.'),
  (2, 'Moderate', 'Mostly comfortable, some focus required.'),
  (3, 'Hard', 'Challenging, required real effort to complete.'),
  (4, 'Very Hard', 'Pushed well beyond comfortable limits.'),
  (5, 'Maximum Effort', 'Extreme difficulty. Barely made it through.'),
];

class PostSessionView extends ConsumerStatefulWidget {
  const PostSessionView({super.key});

  @override
  ConsumerState<PostSessionView> createState() => _PostSessionViewState();
}

class _PostSessionViewState extends ConsumerState<PostSessionView> {
  int? _selectedRpe;
  final _notesController = TextEditingController();
  bool _isBusy = false;
  bool _hasSaved = false;
  int? _savedId;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  SessionResult _buildResult(ExecutionState exec, int ftp) {
    final np = computeNP(exec.powerSamples);
    final tss = computeTSS(exec.totalElapsedSeconds, np, ftp);
    return SessionResult(
      id: _savedId,
      date: DateTime.now(),
      workoutName: exec.workout?.name ?? 'Unnamed Workout',
      durationSeconds: exec.totalElapsedSeconds,
      avgPower: exec.avgPower,
      avgHr: exec.avgHr,
      tss: tss,
      powerSamples: exec.powerSamples,
      hrSamples: exec.hrSamples,
      workoutJson: exec.workout?.toJsonString() ?? '{}',
      rpeRating: _selectedRpe ?? 3,
      notes: _notesController.text.trim(),
    );
  }

  Future<SessionResult> _ensureSaved(
      ExecutionState exec, int ftp) async {
    if (_hasSaved && _savedId != null) {
      return _buildResult(exec, ftp);
    }
    final result = _buildResult(exec, ftp);
    final id = await ref
        .read(sessionHistoryProvider.notifier)
        .save(result);
    setState(() {
      _hasSaved = true;
      _savedId = id;
    });
    return SessionResult(
      id: id,
      date: result.date,
      workoutName: result.workoutName,
      durationSeconds: result.durationSeconds,
      avgPower: result.avgPower,
      avgHr: result.avgHr,
      tss: result.tss,
      powerSamples: result.powerSamples,
      hrSamples: result.hrSamples,
      workoutJson: result.workoutJson,
      rpeRating: result.rpeRating,
      notes: result.notes,
    );
  }

  Future<void> _save(ExecutionState exec, int ftp) async {
    setState(() => _isBusy = true);
    try {
      await _ensureSaved(exec, ftp);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session saved')),
      );
      _navigateAway();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _exportToStrava(ExecutionState exec, int ftp) async {
    setState(() => _isBusy = true);
    try {
      final result = await _ensureSaved(exec, ftp);
      await ref.read(stravaServiceProvider).uploadActivity(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploaded to Strava')),
      );
      _navigateAway();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Strava export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _navigateAway() {
    ref.read(executionProvider.notifier).reset();
    ref.read(selectedViewProvider.notifier).state = AppView.calendar;
  }

  void _skip() {
    ref.read(executionProvider.notifier).reset();
    ref.read(selectedViewProvider.notifier).state = AppView.planner;
  }

  @override
  Widget build(BuildContext context) {
    final exec = ref.watch(executionProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final ftp = settingsAsync.maybeWhen(data: (s) => s.ftp, orElse: () => 0);

    if (exec.status == ExecutionStatus.idle || exec.workout == null) {
      return const Center(
        child: Text('No session data', style: TextStyle(color: Colors.white54)),
      );
    }

    final isPartial =
        exec.totalElapsedSeconds < exec.totalDurationSeconds;
    final duration = _formatDuration(exec.totalElapsedSeconds);
    final np = computeNP(exec.powerSamples);
    final tss = computeTSS(exec.totalElapsedSeconds, np, ftp);
    final canSave = _selectedRpe != null && !_isBusy;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Text(
                isPartial ? 'Session Stopped' : 'Workout Complete',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                exec.workout!.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 24),

              // ── Stats ─────────────────────────────────────────────────
              _StatsRow(
                duration: duration,
                avgPower: exec.avgPower,
                avgHr: exec.avgHr,
                tss: tss,
              ),
              const SizedBox(height: 32),

              // ── RPE survey ────────────────────────────────────────────
              Text('How did this feel?',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ..._rpeOptions.map((opt) {
                final (value, label, description) = opt;
                return RadioListTile<int>(
                  value: value,
                  groupValue: _selectedRpe,
                  onChanged: (v) => setState(() => _selectedRpe = v),
                  title: Text(label),
                  subtitle: Text(description,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white54)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }),
              const SizedBox(height: 24),

              // ── Notes ─────────────────────────────────────────────────
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // ── Actions ───────────────────────────────────────────────
              if (_isBusy)
                const Center(child: CircularProgressIndicator())
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: canSave
                                ? () => _save(exec, ftp)
                                : null,
                            child: const Text('Save'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: canSave
                                ? () => _exportToStrava(exec, ftp)
                                : null,
                            child: const Text('Export to Strava'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _skip,
                        child: const Text('Skip'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.duration,
    required this.avgPower,
    required this.avgHr,
    required this.tss,
  });

  final String duration;
  final int avgPower;
  final int avgHr;
  final double tss;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(label: 'Duration', value: duration),
        const SizedBox(width: 24),
        _Stat(label: 'Avg Power', value: '${avgPower}W'),
        const SizedBox(width: 24),
        _Stat(
            label: 'Avg HR',
            value: avgHr > 0 ? '${avgHr} bpm' : '—'),
        const SizedBox(width: 24),
        _Stat(label: 'TSS', value: tss.toStringAsFixed(1)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white54)),
        Text(value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
