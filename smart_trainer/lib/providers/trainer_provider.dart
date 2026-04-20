import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';
import '../services/ble_scanner.dart';
import '../services/hr_service.dart';
import '../services/trainer_service.dart';

const _kPairedDevicesKey = 'paired_devices';

// ── Services ──────────────────────────────────────────────────────────────────

final bleScannerProvider = Provider<BleScanner>((ref) => BleScanner());

final trainerServiceProvider = Provider<TrainerService>((ref) {
  final svc = TrainerService();
  ref.onDispose(svc.dispose);
  return svc;
});

final hrServiceProvider = Provider<HrService>((ref) {
  final svc = HrService();
  ref.onDispose(svc.dispose);
  return svc;
});

// ── Live data streams ─────────────────────────────────────────────────────────

final livePowerProvider = StreamProvider<int>((ref) {
  return ref.watch(trainerServiceProvider).power;
});

final liveCadenceProvider = StreamProvider<int>((ref) {
  return ref.watch(trainerServiceProvider).cadence;
});

final liveHeartRateProvider = StreamProvider<int>((ref) {
  return ref.watch(hrServiceProvider).heartRate;
});

final trainerConnectionProvider =
    StreamProvider<BluetoothConnectionState>((ref) {
  return ref.watch(trainerServiceProvider).connectionState;
});

final hrConnectionProvider =
    StreamProvider<BluetoothConnectionState>((ref) {
  return ref.watch(hrServiceProvider).connectionState;
});

// ── Paired devices ────────────────────────────────────────────────────────────

class PairedDevicesNotifier extends AsyncNotifier<List<DeviceInfo>> {
  @override
  Future<List<DeviceInfo>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kPairedDevicesKey) ?? [];
    return raw
        .map((s) => DeviceInfo.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> addDevice(DeviceInfo info) async {
    final current = state.valueOrNull ?? [];
    // One device per type — replace if same type already paired.
    final updated = [
      ...current.where((d) => d.type != info.type),
      info,
    ];
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> removeDevice(String deviceId) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((d) => d.id != deviceId).toList();
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> _persist(List<DeviceInfo> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kPairedDevicesKey,
      devices.map((d) => jsonEncode(d.toJson())).toList(),
    );
  }
}

final pairedDevicesProvider =
    AsyncNotifierProvider<PairedDevicesNotifier, List<DeviceInfo>>(
  PairedDevicesNotifier.new,
);
