import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleScanner {
  Stream<List<ScanResult>> startScan(List<String> filterServiceUuids) {
    FlutterBluePlus.startScan(
      withServices: filterServiceUuids.map(Guid.new).toList(),
      timeout: const Duration(seconds: 10),
    );
    return FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();
}
