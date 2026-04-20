import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const kTacxServiceUuid = '6e40fec1-b5a3-f393-e0a9-e50e24dcca9e';
const kTacxWriteUuid = '6e40fec2-b5a3-f393-e0a9-e50e24dcca9e';
const kTacxNotifyUuid = '6e40fec3-b5a3-f393-e0a9-e50e24dcca9e';

class TrainerService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _intentionalDisconnect = false;
  int _reconnectDelay = 2;

  final _powerCtrl = StreamController<int>.broadcast();
  final _cadenceCtrl = StreamController<int>.broadcast();
  final _connCtrl = StreamController<BluetoothConnectionState>.broadcast();

  Stream<int> get power => _powerCtrl.stream;
  Stream<int> get cadence => _cadenceCtrl.stream;
  Stream<BluetoothConnectionState> get connectionState => _connCtrl.stream;

  Future<void> connect(String deviceId) async {
    _intentionalDisconnect = false;
    _reconnectDelay = 2;
    _device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
    await _connectDevice();
  }

  Future<void> _connectDevice() async {
    if (_device == null) return;
    try {
      await _device!.connect(autoConnect: false);
      _reconnectDelay = 2;

      final services = await _device!.discoverServices();
      final svc = services.firstWhere(
        (s) => s.serviceUuid == Guid(kTacxServiceUuid),
      );
      _writeChar = svc.characteristics.firstWhere(
        (c) => c.characteristicUuid == Guid(kTacxWriteUuid),
      );
      final notifyChar = svc.characteristics.firstWhere(
        (c) => c.characteristicUuid == Guid(kTacxNotifyUuid),
      );

      await notifyChar.setNotifyValue(true);
      _notifySub?.cancel();
      _notifySub = notifyChar.onValueReceived.listen(_parseFecNotify);

      _connSub?.cancel();
      _connSub = _device!.connectionState.listen((state) {
        _connCtrl.add(state);
        if (state == BluetoothConnectionState.disconnected &&
            !_intentionalDisconnect) {
          _scheduleReconnect();
        }
      });

      _connCtrl.add(BluetoothConnectionState.connected);
    } catch (_) {
      if (!_intentionalDisconnect) _scheduleReconnect();
    }
  }

  void _scheduleReconnect() async {
    await Future.delayed(Duration(seconds: _reconnectDelay));
    _reconnectDelay = (_reconnectDelay * 2).clamp(2, 30);
    if (!_intentionalDisconnect) await _connectDevice();
  }

  // FE-C page 25 (0x19) — Trainer-Specific Data.
  // Handles both full ANT+ frame (sync byte 0xA4 at [0]) and raw 8-byte payload.
  void _parseFecNotify(List<int> data) {
    final offset = (data.isNotEmpty && data[0] == 0xA4) ? 4 : 0;
    if (data.length < offset + 7) return;
    if (data[offset] != 0x19) return;

    final cadenceRaw = data[offset + 2];
    if (cadenceRaw != 0xFF) _cadenceCtrl.add(cadenceRaw);

    final power = data[offset + 5] | ((data[offset + 6] & 0x0F) << 8);
    _powerCtrl.add(power);
  }

  // FE-C page 49 (0x31) ERG command. Power encoded in 0.25 W units.
  // Checksum = XOR of frame bytes 1–11.
  Future<void> setTargetPower(int watts) async {
    if (_writeChar == null) return;
    final encoded = watts * 4;
    final powerLow = encoded & 0xFF;
    final powerHigh = (encoded >> 8) & 0xFF;

    final frame = [
      0xA4, 0x09, 0x4F, 0x05, 0x31,
      0xFF, 0xFF, 0xFF, 0xFF,
      powerLow, powerHigh, 0xFF,
    ];
    var checksum = 0;
    for (var i = 1; i < frame.length; i++) {
      checksum ^= frame[i];
    }
    frame.add(checksum);

    await _writeChar!.write(frame, withoutResponse: false);
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _notifySub?.cancel();
    _connSub?.cancel();
    await _device?.disconnect();
    _writeChar = null;
    _connCtrl.add(BluetoothConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _powerCtrl.close();
    _cadenceCtrl.close();
    _connCtrl.close();
  }
}
