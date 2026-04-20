import 'package:flutter/material.dart';
import '../../../models/session_result.dart';

const _rpeLabels = ['', 'Easy', 'Moderate', 'Hard', 'Very Hard', 'Maximum Effort'];

void showSessionDetailSheet(BuildContext context, SessionResult session) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _SessionDetailSheet(session: session),
  );
}

class _SessionDetailSheet extends StatelessWidget {
  const _SessionDetailSheet({required this.session});

  final SessionResult session;

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final date = session.date;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
          Text(session.workoutName,
              style: Theme.of(context).textTheme.titleLarge),
          Text(dateStr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 16),
          _StatsRow(session: session, fmtDuration: _fmtDuration),
          const SizedBox(height: 12),
          _StatTile(label: 'RPE', value: _rpeLabels[session.rpeRating.clamp(1, 5)]),
          if (session.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Notes', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(session.notes),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.session, required this.fmtDuration});

  final SessionResult session;
  final String Function(int) fmtDuration;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatTile(label: 'Duration', value: fmtDuration(session.durationSeconds)),
        _StatTile(label: 'Avg Power', value: '${session.avgPower}W'),
        _StatTile(label: 'Avg HR', value: '${session.avgHr} bpm'),
        _StatTile(label: 'TSS', value: session.tss.toStringAsFixed(0)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }
}
