import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const kHrServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
const kHrMeasurementUuid = '00002a37-0000-1000-8000-00805f9b34fb';

class HrService {
  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _intentionalDisconnect = false;
  int _reconnectDelay = 2;

  final _hrCtrl = StreamController<int>.broadcast();
  final _connCtrl = StreamController<BluetoothConnectionState>.broadcast();

  Stream<int> get heartRate => _hrCtrl.stream;
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
        (s) => s.serviceUuid == Guid(kHrServiceUuid),
      );
      final hrChar = svc.characteristics.firstWhere(
        (c) => c.characteristicUuid == Guid(kHrMeasurementUuid),
      );

      await hrChar.setNotifyValue(true);
      _notifySub?.cancel();
      _notifySub = hrChar.onValueReceived.listen(_parseHrMeasurement);

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

  // Heart Rate Measurement characteristic (0x2A37).
  // flags bit 0 = 0 → HR is uint8 at byte 1; bit 0 = 1 → HR is uint16 LE at bytes 1-2.
  void _parseHrMeasurement(List<int> data) {
    if (data.length < 2) return;
    final flags = data[0];
    final hr = (flags & 0x01) == 0 ? data[1] : (data[1] | (data[2] << 8));
    _hrCtrl.add(hr);
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _notifySub?.cancel();
    _connSub?.cancel();
    await _device?.disconnect();
    _connCtrl.add(BluetoothConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _hrCtrl.close();
    _connCtrl.close();
  }
}
