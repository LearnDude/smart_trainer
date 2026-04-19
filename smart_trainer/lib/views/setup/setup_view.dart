import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_settings.dart';
import '../../providers/settings_provider.dart';

const _powerZoneLabels = [
  'Z1 — Active Recovery',
  'Z2 — Endurance',
  'Z3 — Tempo',
  'Z4 — Lactate Threshold',
  'Z5 — VO2 Max',
  'Z6 — Anaerobic Capacity',
];

const _hrZoneLabels = [
  'Z1 — Recovery',
  'Z2 — Aerobic',
  'Z3 — Tempo',
  'Z4 — Threshold',
];

class SetupView extends ConsumerStatefulWidget {
  const SetupView({super.key});

  @override
  ConsumerState<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends ConsumerState<SetupView> {
  final _formKey = GlobalKey<FormState>();

  final _ftpCtrl = TextEditingController();
  final _vt1Ctrl = TextEditingController();
  final _vt2Ctrl = TextEditingController();
  final _maxHrCtrl = TextEditingController();

  final List<TextEditingController> _powerZoneCtrs =
      List.generate(6, (_) => TextEditingController());
  final List<TextEditingController> _hrZoneCtrs =
      List.generate(4, (_) => TextEditingController());

  bool _useCustomPower = false;
  bool _useCustomHr = false;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _ftpCtrl.dispose();
    _vt1Ctrl.dispose();
    _vt2Ctrl.dispose();
    _maxHrCtrl.dispose();
    for (final c in _powerZoneCtrs) {
      c.dispose();
    }
    for (final c in _hrZoneCtrs) {
      c.dispose();
    }
    super.dispose();
  }

  void _populate(UserSettings s) {
    if (_initialized) return;
    _initialized = true;

    _ftpCtrl.text = s.ftp > 0 ? '${s.ftp}' : '';
    _vt1Ctrl.text = s.vt1 > 0 ? '${s.vt1}' : '';
    _vt2Ctrl.text = s.vt2 > 0 ? '${s.vt2}' : '';
    _maxHrCtrl.text = s.maxHr > 0 ? '${s.maxHr}' : '';

    if (s.customPowerZones != null) {
      _useCustomPower = true;
      for (var i = 0; i < s.customPowerZones!.length && i < 6; i++) {
        _powerZoneCtrs[i].text = '${s.customPowerZones![i]}';
      }
    }

    if (s.customHrZones != null) {
      _useCustomHr = true;
      for (var i = 0; i < s.customHrZones!.length && i < 4; i++) {
        _hrZoneCtrs[i].text = '${s.customHrZones![i]}';
      }
    }
  }

  void _fillDefaultPowerZones() {
    final ftp = int.tryParse(_ftpCtrl.text) ?? 0;
    if (ftp == 0) return;
    final defaults = [
      (ftp * 0.55).round(),
      (ftp * 0.75).round(),
      (ftp * 0.90).round(),
      (ftp * 1.05).round(),
      (ftp * 1.20).round(),
      (ftp * 1.50).round(),
    ];
    for (var i = 0; i < 6; i++) {
      if (_powerZoneCtrs[i].text.isEmpty) {
        _powerZoneCtrs[i].text = '${defaults[i]}';
      }
    }
  }

  void _fillDefaultHrZones() {
    final maxHr = int.tryParse(_maxHrCtrl.text) ?? 0;
    if (maxHr == 0) return;
    final defaults = [
      (maxHr * 0.60).round(),
      (maxHr * 0.70).round(),
      (maxHr * 0.80).round(),
      (maxHr * 0.90).round(),
    ];
    for (var i = 0; i < 4; i++) {
      if (_hrZoneCtrs[i].text.isEmpty) {
        _hrZoneCtrs[i].text = '${defaults[i]}';
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final settings = UserSettings(
      ftp: int.parse(_ftpCtrl.text),
      vt1: int.tryParse(_vt1Ctrl.text) ?? 0,
      vt2: int.tryParse(_vt2Ctrl.text) ?? 0,
      maxHr: int.tryParse(_maxHrCtrl.text) ?? 0,
      customPowerZones: _useCustomPower
          ? _powerZoneCtrs.map((c) => int.parse(c.text)).toList()
          : null,
      customHrZones: _useCustomHr
          ? _hrZoneCtrs.map((c) => int.parse(c.text)).toList()
          : null,
    );

    await ref.read(settingsProvider.notifier).save(settings);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading settings: $e')),
      data: (settings) {
        _populate(settings);
        return _buildForm(context);
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        children: [
          Text('Performance Metrics', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Used to compute power zones and personalise training plans.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          _MetricField(
            controller: _ftpCtrl,
            label: 'FTP *',
            unit: 'W',
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Required — enter your FTP in watts';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _MetricField(
            controller: _vt1Ctrl,
            label: 'VT1 — first ventilatory threshold',
            unit: 'W',
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              final n = int.tryParse(v);
              if (n == null || n <= 0) return 'Must be a positive number';
              final ftp = int.tryParse(_ftpCtrl.text) ?? 0;
              if (ftp > 0 && n >= ftp) return 'VT1 should be below FTP ($ftp W)';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _MetricField(
            controller: _vt2Ctrl,
            label: 'VT2 — second ventilatory threshold',
            unit: 'W',
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              final n = int.tryParse(v);
              if (n == null || n <= 0) return 'Must be a positive number';
              final vt1 = int.tryParse(_vt1Ctrl.text) ?? 0;
              if (vt1 > 0 && n <= vt1) return 'VT2 must be above VT1 ($vt1 W)';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _MetricField(
            controller: _maxHrCtrl,
            label: 'Max Heart Rate',
            unit: 'bpm',
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              final n = int.tryParse(v);
              if (n == null || n <= 0) return 'Must be a positive number';
              if (n > 230) return 'Double-check — seems high';
              return null;
            },
          ),

          const SizedBox(height: 32),

          ExpansionTile(
            title: const Text('Custom Power Zones'),
            subtitle: const Text(
              'Optional — defaults use Coggan 7-zone model from FTP',
            ),
            initiallyExpanded: _useCustomPower,
            onExpansionChanged: (expanded) {
              setState(() => _useCustomPower = expanded);
              if (expanded) _fillDefaultPowerZones();
            },
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Upper bound (W) for each zone. Zone 7 is open-ended.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              for (var i = 0; i < 6; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: _MetricField(
                    controller: _powerZoneCtrs[i],
                    label: _powerZoneLabels[i],
                    unit: 'W',
                    validator: _useCustomPower
                        ? (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Required';
                            if (i > 0) {
                              final prev =
                                  int.tryParse(_powerZoneCtrs[i - 1].text) ?? 0;
                              if (n <= prev) {
                                return 'Must be above Z$i upper ($prev W)';
                              }
                            }
                            return null;
                          }
                        : null,
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),

          const SizedBox(height: 8),

          ExpansionTile(
            title: const Text('Custom HR Zones'),
            subtitle: const Text(
              'Optional — defaults use 5-zone model from max HR',
            ),
            initiallyExpanded: _useCustomHr,
            onExpansionChanged: (expanded) {
              setState(() => _useCustomHr = expanded);
              if (expanded) _fillDefaultHrZones();
            },
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Upper bound (bpm) for each zone. Zone 5 is open-ended.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: _MetricField(
                    controller: _hrZoneCtrs[i],
                    label: _hrZoneLabels[i],
                    unit: 'bpm',
                    validator: _useCustomHr
                        ? (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Required';
                            if (i > 0) {
                              final prev =
                                  int.tryParse(_hrZoneCtrs[i - 1].text) ?? 0;
                              if (n <= prev) {
                                return 'Must be above Z$i upper ($prev bpm)';
                              }
                            }
                            return null;
                          }
                        : null,
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),

          const SizedBox(height: 32),

          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricField extends StatelessWidget {
  const _MetricField({
    required this.controller,
    required this.label,
    required this.unit,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String unit;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: validator,
    );
  }
}
