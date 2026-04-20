import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/workout.dart';
import '../../providers/execution_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/planner_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/trainer_provider.dart';
import '../../widgets/workout_block_chart.dart';

class EditorView extends ConsumerStatefulWidget {
  const EditorView({super.key, this.initialWorkout});

  final Workout? initialWorkout;

  @override
  ConsumerState<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends ConsumerState<EditorView> {
  late final TextEditingController _nameCtrl;
  late List<_Entry> _entries;
  int _nextKey = 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.initialWorkout?.name ?? 'New Workout',
    );
    _entries = (widget.initialWorkout?.steps ?? [])
        .map((s) => _Entry(_nextKey++, s))
        .toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Workout get _workout => Workout(
        name: _nameCtrl.text.trim().isEmpty ? 'Workout' : _nameCtrl.text.trim(),
        steps: _entries.map((e) => e.step).toList(),
      );

  void _addStep(String type) {
    final step = switch (type) {
      'interval' => IntervalBlock(
          reps: 3,
          on: const SteadyState(
              duration: Duration(minutes: 3), power: WattsTarget(250)),
          off: const SteadyState(
              duration: Duration(minutes: 2), power: WattsTarget(100)),
        ),
      'ramp' => const Ramp(
          duration: Duration(minutes: 10),
          from: WattsTarget(150),
          to: WattsTarget(250),
        ),
      _ => const SteadyState(
          duration: Duration(minutes: 5), power: WattsTarget(150)),
    };
    setState(() => _entries = [..._entries, _Entry(_nextKey++, step)]);
  }

  Future<void> _editStep(int index) async {
    final result = await showDialog<WorkoutStep>(
      context: context,
      builder: (_) => _StepDialog(step: _entries[index].step),
    );
    if (result != null) {
      setState(() {
        final list = [..._entries];
        list[index] = _entries[index].copyWith(result);
        _entries = list;
      });
    }
  }

  void _deleteStep(int index) {
    setState(() {
      final list = [..._entries];
      list.removeAt(index);
      _entries = list;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final list = [..._entries];
      final entry = list.removeAt(oldIndex);
      list.insert(newIndex, entry);
      _entries = list;
    });
  }

  Future<void> _saveToLibrary() async {
    await ref.read(plannerProvider.notifier).saveToLibrary(_workout);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "${_workout.name}" to Library')),
      );
    }
  }

  Future<void> _startWorkout() async {
    final conn = ref.read(trainerConnectionProvider).valueOrNull;
    if (conn != BluetoothConnectionState.connected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trainer not connected — pair it in Setup first'),
        ),
      );
      return;
    }
    final ftp = ref.read(settingsProvider).maybeWhen(
          data: (s) => s.ftp,
          orElse: () => 0,
        );
    if (ftp == 0) return;
    await ref.read(executionProvider.notifier).startWorkout(_workout, ftp);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(selectedViewProvider.notifier).state = AppView.execution;
  }

  @override
  Widget build(BuildContext context) {
    final ftp = ref.watch(settingsProvider).maybeWhen(
          data: (s) => s.ftp,
          orElse: () => 200,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Editor')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 380,
            child: _StepListPanel(
              nameCtrl: _nameCtrl,
              entries: _entries,
              ftp: ftp,
              onNameChanged: (_) => setState(() {}),
              onAddStep: _addStep,
              onEditStep: _editStep,
              onDeleteStep: _deleteStep,
              onReorder: _onReorder,
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: _PreviewPanel(
              workout: _workout,
              ftp: ftp,
              onSaveToLibrary: _saveToLibrary,
              onStart: _startWorkout,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Entry (step + stable key for ReorderableListView) ─────────────────────────

class _Entry {
  const _Entry(this.key, this.step);
  final int key;
  final WorkoutStep step;

  _Entry copyWith(WorkoutStep s) => _Entry(key, s);
}

// ── Left panel — step list ────────────────────────────────────────────────────

class _StepListPanel extends StatelessWidget {
  const _StepListPanel({
    required this.nameCtrl,
    required this.entries,
    required this.ftp,
    required this.onNameChanged,
    required this.onAddStep,
    required this.onEditStep,
    required this.onDeleteStep,
    required this.onReorder,
  });

  final TextEditingController nameCtrl;
  final List<_Entry> entries;
  final int ftp;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onAddStep;
  final ValueChanged<int> onEditStep;
  final ValueChanged<int> onDeleteStep;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            style: theme.textTheme.titleLarge,
            decoration: const InputDecoration(
              hintText: 'Workout name',
              border: InputBorder.none,
            ),
            onChanged: onNameChanged,
          ),
          const SizedBox(height: 4),
          Text(
            '${entries.length} step${entries.length == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'No steps yet — add one below.',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: entries.length,
                    onReorder: onReorder,
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, i) => _StepCard(
                      key: ValueKey(entries[i].key),
                      index: i,
                      step: entries[i].step,
                      ftp: ftp,
                      onEdit: () => onEditStep(i),
                      onDelete: () => onDeleteStep(i),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          _AddStepButton(onAdd: onAddStep),
        ],
      ),
    );
  }
}

// ── Step card ─────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.index,
    required this.step,
    required this.ftp,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final WorkoutStep step;
  final int ftp;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.drag_handle, size: 20),
          ),
        ),
        title: Text(_title),
        subtitle: Text(_subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String get _title => switch (step) {
        SteadyState _ => 'Steady State',
        IntervalBlock i => 'Interval ×${i.reps}',
        Ramp _ => 'Ramp',
      };

  String get _subtitle => switch (step) {
        SteadyState s =>
          '${formatDuration(s.duration)}  ·  ${describePower(s.power, ftp)}',
        IntervalBlock i =>
          '${formatDuration(i.on.duration)} on @ ${describePower(i.on.power, ftp)}'
              '  /  ${formatDuration(i.off.duration)} off @ ${describePower(i.off.power, ftp)}',
        Ramp r =>
          '${formatDuration(r.duration)}  ·  ${describePower(r.from, ftp)} → ${describePower(r.to, ftp)}',
      };
}

// ── Add step button ───────────────────────────────────────────────────────────

class _AddStepButton extends StatelessWidget {
  const _AddStepButton({required this.onAdd});

  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.add),
        label: const Text('Add Step'),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => onAdd('steady'),
          child: const Text('Steady State'),
        ),
        MenuItemButton(
          onPressed: () => onAdd('interval'),
          child: const Text('Interval'),
        ),
        MenuItemButton(
          onPressed: () => onAdd('ramp'),
          child: const Text('Ramp'),
        ),
      ],
    );
  }
}

// ── Right panel — live preview ────────────────────────────────────────────────

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.workout,
    required this.ftp,
    required this.onSaveToLibrary,
    required this.onStart,
  });

  final Workout workout;
  final int ftp;
  final VoidCallback onSaveToLibrary;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Preview', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 80,
            child: WorkoutBlockChart(workout: workout, ftp: ftp),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          formatDuration(workout.totalDuration),
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onSaveToLibrary,
              icon: const Icon(Icons.bookmark_outline),
              label: const Text('Save to Library'),
            ),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Start Workout'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Step edit dialog ──────────────────────────────────────────────────────────

class _StepDialog extends StatefulWidget {
  const _StepDialog({required this.step});
  final WorkoutStep step;

  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  late String _type;

  // Duration (Steady + Ramp)
  final _durMinCtrl = TextEditingController();
  final _durSecCtrl = TextEditingController();

  // Steady power
  String _powerUnit = 'W';
  final _powerCtrl = TextEditingController();

  // Interval
  final _repsCtrl = TextEditingController();
  String _onUnit = 'W';
  final _onMinCtrl = TextEditingController();
  final _onSecCtrl = TextEditingController();
  final _onPowerCtrl = TextEditingController();
  String _offUnit = 'W';
  final _offMinCtrl = TextEditingController();
  final _offSecCtrl = TextEditingController();
  final _offPowerCtrl = TextEditingController();

  // Ramp
  String _fromUnit = 'W';
  final _fromCtrl = TextEditingController();
  String _toUnit = 'W';
  final _toCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _populate(widget.step);
  }

  void _populate(WorkoutStep step) {
    switch (step) {
      case SteadyState s:
        _type = 'steady';
        _durMinCtrl.text = '${s.duration.inMinutes}';
        _durSecCtrl.text = '${s.duration.inSeconds.remainder(60)}';
        _setCtrl(s.power, _powerCtrl, (u) => _powerUnit = u);
        _repsCtrl.text = '3';
        _onMinCtrl.text = '3'; _onSecCtrl.text = '0';
        _onPowerCtrl.text = '250'; _onUnit = 'W';
        _offMinCtrl.text = '2'; _offSecCtrl.text = '0';
        _offPowerCtrl.text = '100'; _offUnit = 'W';
        _fromCtrl.text = '150'; _fromUnit = 'W';
        _toCtrl.text = '250'; _toUnit = 'W';
      case IntervalBlock i:
        _type = 'interval';
        _repsCtrl.text = '${i.reps}';
        _onMinCtrl.text = '${i.on.duration.inMinutes}';
        _onSecCtrl.text = '${i.on.duration.inSeconds.remainder(60)}';
        _setCtrl(i.on.power, _onPowerCtrl, (u) => _onUnit = u);
        _offMinCtrl.text = '${i.off.duration.inMinutes}';
        _offSecCtrl.text = '${i.off.duration.inSeconds.remainder(60)}';
        _setCtrl(i.off.power, _offPowerCtrl, (u) => _offUnit = u);
        _durMinCtrl.text = '5'; _durSecCtrl.text = '0';
        _powerCtrl.text = '150'; _powerUnit = 'W';
        _fromCtrl.text = '150'; _fromUnit = 'W';
        _toCtrl.text = '250'; _toUnit = 'W';
      case Ramp r:
        _type = 'ramp';
        _durMinCtrl.text = '${r.duration.inMinutes}';
        _durSecCtrl.text = '${r.duration.inSeconds.remainder(60)}';
        _setCtrl(r.from, _fromCtrl, (u) => _fromUnit = u);
        _setCtrl(r.to, _toCtrl, (u) => _toUnit = u);
        _powerCtrl.text = '150'; _powerUnit = 'W';
        _repsCtrl.text = '3';
        _onMinCtrl.text = '3'; _onSecCtrl.text = '0';
        _onPowerCtrl.text = '250'; _onUnit = 'W';
        _offMinCtrl.text = '2'; _offSecCtrl.text = '0';
        _offPowerCtrl.text = '100'; _offUnit = 'W';
    }
  }

  void _setCtrl(
      PowerTarget p, TextEditingController ctrl, void Function(String) setUnit) {
    switch (p) {
      case WattsTarget w:
        ctrl.text = '${w.watts}';
        setUnit('W');
      case FtpPercentTarget f:
        ctrl.text = '${(f.percent * 100).round()}';
        setUnit('%');
    }
  }

  PowerTarget _buildPower(TextEditingController ctrl, String unit) {
    final n = int.tryParse(ctrl.text) ?? 0;
    return unit == 'W' ? WattsTarget(n) : FtpPercentTarget(n / 100.0);
  }

  Duration _buildDur(
          TextEditingController minCtrl, TextEditingController secCtrl) =>
      Duration(
        minutes: int.tryParse(minCtrl.text) ?? 0,
        seconds: int.tryParse(secCtrl.text) ?? 0,
      );

  WorkoutStep _buildStep() => switch (_type) {
        'interval' => IntervalBlock(
            reps: int.tryParse(_repsCtrl.text) ?? 1,
            on: SteadyState(
              duration: _buildDur(_onMinCtrl, _onSecCtrl),
              power: _buildPower(_onPowerCtrl, _onUnit),
            ),
            off: SteadyState(
              duration: _buildDur(_offMinCtrl, _offSecCtrl),
              power: _buildPower(_offPowerCtrl, _offUnit),
            ),
          ),
        'ramp' => Ramp(
            duration: _buildDur(_durMinCtrl, _durSecCtrl),
            from: _buildPower(_fromCtrl, _fromUnit),
            to: _buildPower(_toCtrl, _toUnit),
          ),
        _ => SteadyState(
            duration: _buildDur(_durMinCtrl, _durSecCtrl),
            power: _buildPower(_powerCtrl, _powerUnit),
          ),
      };

  @override
  void dispose() {
    _durMinCtrl.dispose();
    _durSecCtrl.dispose();
    _powerCtrl.dispose();
    _repsCtrl.dispose();
    _onMinCtrl.dispose();
    _onSecCtrl.dispose();
    _onPowerCtrl.dispose();
    _offMinCtrl.dispose();
    _offSecCtrl.dispose();
    _offPowerCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Step'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'steady', child: Text('Steady State')),
                  DropdownMenuItem(
                      value: 'interval', child: Text('Interval')),
                  DropdownMenuItem(value: 'ramp', child: Text('Ramp')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 20),
              ..._buildTypeFields(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_buildStep()),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  List<Widget> _buildTypeFields() => switch (_type) {
        'interval' => [
            _DurRow('Duration ON', _onMinCtrl, _onSecCtrl),
            const SizedBox(height: 8),
            _PowerRow(
              label: 'Power ON',
              ctrl: _onPowerCtrl,
              unit: _onUnit,
              onUnit: (u) => setState(() => _onUnit = u),
            ),
            const SizedBox(height: 16),
            _DurRow('Duration OFF', _offMinCtrl, _offSecCtrl),
            const SizedBox(height: 8),
            _PowerRow(
              label: 'Power OFF',
              ctrl: _offPowerCtrl,
              unit: _offUnit,
              onUnit: (u) => setState(() => _offUnit = u),
            ),
            const SizedBox(height: 16),
            _IntField(label: 'Repetitions', ctrl: _repsCtrl),
          ],
        'ramp' => [
            _DurRow('Duration', _durMinCtrl, _durSecCtrl),
            const SizedBox(height: 8),
            _PowerRow(
              label: 'FROM',
              ctrl: _fromCtrl,
              unit: _fromUnit,
              onUnit: (u) => setState(() => _fromUnit = u),
            ),
            const SizedBox(height: 8),
            _PowerRow(
              label: 'TO',
              ctrl: _toCtrl,
              unit: _toUnit,
              onUnit: (u) => setState(() => _toUnit = u),
            ),
          ],
        _ => [
            _DurRow('Duration', _durMinCtrl, _durSecCtrl),
            const SizedBox(height: 8),
            _PowerRow(
              label: 'Power',
              ctrl: _powerCtrl,
              unit: _powerUnit,
              onUnit: (u) => setState(() => _powerUnit = u),
            ),
          ],
      };
}

// ── Dialog field helpers ──────────────────────────────────────────────────────

class _DurRow extends StatelessWidget {
  const _DurRow(this.label, this.minCtrl, this.secCtrl);

  final String label;
  final TextEditingController minCtrl;
  final TextEditingController secCtrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: minCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: '$label (min)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: TextFormField(
            controller: secCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'sec',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _PowerRow extends StatelessWidget {
  const _PowerRow({
    required this.label,
    required this.ctrl,
    required this.unit,
    required this.onUnit,
  });

  final String label;
  final TextEditingController ctrl;
  final String unit;
  final ValueChanged<String> onUnit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: unit,
          items: const [
            DropdownMenuItem(value: 'W', child: Text('W')),
            DropdownMenuItem(value: '%', child: Text('% FTP')),
          ],
          onChanged: (v) {
            if (v != null) onUnit(v);
          },
        ),
      ],
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({required this.label, required this.ctrl});

  final String label;
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
