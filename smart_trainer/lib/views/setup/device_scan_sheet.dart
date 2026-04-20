import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/device_info.dart';
import '../../providers/trainer_provider.dart';
import '../../services/hr_service.dart';
import '../../services/trainer_service.dart';

class DeviceScanSheet extends ConsumerStatefulWidget {
  const DeviceScanSheet({super.key, required this.deviceType});

  final DeviceType deviceType;

  @override
  ConsumerState<DeviceScanSheet> createState() => _DeviceScanSheetState();
}

class _DeviceScanSheetState extends ConsumerState<DeviceScanSheet> {
  StreamSubscription<List<ScanResult>>? _scanSub;
  List<ScanResult> _results = [];
  bool _scanning = false;
  String? _pairingId;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    ref.read(bleScannerProvider).stopScan();
    super.dispose();
  }

  String get _serviceUuid => switch (widget.deviceType) {
        DeviceType.trainer => kTacxServiceUuid,
        DeviceType.heartRate => kHrServiceUuid,
        DeviceType.cadence => '00001816-0000-1000-8000-00805f9b34fb',
      };

  String get _typeLabel => switch (widget.deviceType) {
        DeviceType.trainer => 'Trainer',
        DeviceType.heartRate => 'HR Monitor',
        DeviceType.cadence => 'Cadence Sensor',
      };

  void _startScan() {
    setState(() {
      _scanning = true;
      _results = [];
    });
    final scanner = ref.read(bleScannerProvider);
    _scanSub?.cancel();
    _scanSub = scanner.startScan([_serviceUuid]).listen((results) {
      if (mounted) setState(() => _results = results);
    });
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) setState(() => _scanning = false);
    });
  }

  Future<void> _pair(ScanResult result) async {
    final id = result.device.remoteId.str;
    setState(() => _pairingId = id);

    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : id;
    final info = DeviceInfo(id: id, name: name, type: widget.deviceType);

    await ref.read(pairedDevicesProvider.notifier).addDevice(info);

    switch (info.type) {
      case DeviceType.trainer:
        ref.read(trainerServiceProvider).connect(info.id);
      case DeviceType.heartRate:
        ref.read(hrServiceProvider).connect(info.id);
      case DeviceType.cadence:
        break;
    }

    if (mounted) Navigator.of(context).pop(info);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Add $_typeLabel',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (_scanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    TextButton(
                      onPressed: _startScan,
                      child: const Text('Scan again'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _scanning
                            ? 'Scanning for devices…'
                            : 'No devices found.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final r = _results[i];
                        final id = r.device.remoteId.str;
                        final name = r.device.platformName.isNotEmpty
                            ? r.device.platformName
                            : id;
                        final pairing = _pairingId == id;
                        return ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: Text(name),
                          subtitle: Text(id),
                          trailing: pairing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text('${r.rssi} dBm'),
                          onTap: _pairingId == null ? () => _pair(r) : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
