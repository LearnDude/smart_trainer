# Phase 3 — BLE / Trainer Service

## Goal

Connect to the TacX Flux trainer, a heart rate monitor, and an optional cadence sensor over Bluetooth LE. Expose live data streams via Riverpod. Add a Device Setup screen for pairing and persisting device addresses.

---

## New files

| File | Purpose |
|---|---|
| `lib/services/trainer_service.dart` | FE-C BLE connection + ERG commands + notify parsing |
| `lib/services/hr_service.dart` | Standard BLE Heart Rate Service (UUID 0x180D) |
| `lib/services/cadence_service.dart` | BLE CSC Service (UUID 0x1816) — only if no cadence in FE-C data |
| `lib/services/ble_scanner.dart` | Shared scan logic; returns `ScanResult` streams |
| `lib/providers/trainer_provider.dart` | Riverpod providers exposing streams and commands |
| `lib/models/device_info.dart` | `DeviceInfo(id, name, type)` — stored to `shared_preferences` |
| `lib/views/setup/device_scan_sheet.dart` | Bottom sheet opened from SetupView: live scan results, tap to pair |

**No new nav view.** Pairing UI is a sub-section inside `SetupView`, not a separate screen.

---

## UUIDs / protocol constants

```dart
// TacX FE-C over BLE
const kTacxServiceUuid     = '6e40fec1-b5a3-f393-e0a9-e50e24dcca9e';
const kTacxWriteUuid       = '6e40fec2-b5a3-f393-e0a9-e50e24dcca9e';
const kTacxNotifyUuid      = '6e40fec3-b5a3-f393-e0a9-e50e24dcca9e';

// Heart Rate
const kHrServiceUuid       = '0000180d-0000-1000-8000-00805f9b34fb';
const kHrMeasurementUuid   = '00002a37-0000-1000-8000-00805f9b34fb';

// Cycling Speed & Cadence
const kCscServiceUuid      = '00001816-0000-1000-8000-00805f9b34fb';
const kCscMeasurementUuid  = '00002a5b-0000-1000-8000-00805f9b34fb';
```

---

## `TrainerService`

```
class TrainerService {
  Stream<int>                       power             // watts from FE-C notify
  Stream<int>                       cadence           // rpm from FE-C notify (page 25)
  Stream<BluetoothConnectionState>  connectionState   // flutter_blue_plus type, no custom wrapper

  Future<void> connect(String deviceId)
  Future<void> disconnect()
  Future<void> setTargetPower(int watts)   // FE-C page 49 (0x31), encoded as watts*4
  Future<void> _reconnectLoop()            // retries on disconnect
}
```

**FE-C notify parsing** — page 25 Trainer-Specific Data (`0x19`):
- Byte 2: instantaneous cadence (uint8, rpm; 0xFF = invalid/not available)
- Bytes 5–6: instantaneous power (12-bit, little-endian split):
  - bits 0–7 of the 12-bit value come from byte 5 (full byte)
  - bits 8–11 come from the upper 4 bits of byte 6

**ERG command** — page 49 (`0x31`), full ANT+ frame required by the TacX BLE tunnel:
```
[0xA4, 0x09, 0x4F, 0x05, 0x31, 0xFF, 0xFF, 0xFF, 0xFF, power_low, power_high, 0xFF, checksum]
```
- Message type is `0x4F` (acknowledged data), not `0x4E`
- Power is encoded in units of 0.25 W: `encodedPower = watts * 4`; split as uint16 little-endian into `power_low` and `power_high`
- Checksum is XOR of all bytes from index 1 to 11 (inclusive)

---

## `BleHrService`

Connects to the paired HR monitor. Parses the Heart Rate Measurement characteristic:
- byte 0 bit 0 = 0 → HR in byte 1 (uint8)
- byte 0 bit 0 = 1 → HR in bytes 1–2 (uint16 little-endian)

Exposes `Stream<int> heartRate`.

---

## `BleScanner`

Provided via `Provider<BleScanner>` (consistent with the Riverpod architecture — not a Dart singleton). `startScan(List<String> filterServiceUuids)` returns a `Stream<List<ScanResult>>`. Stops automatically after 10 s or on explicit `stopScan()`.

---

## Riverpod providers (`trainer_provider.dart`)

```dart
final bleScannerProvider           = Provider<BleScanner>(...);
final trainerServiceProvider       = Provider<TrainerService>(...);
final hrServiceProvider            = Provider<HrService>(...);

// Broadcast streams as StreamProviders (names match providers.md)
final livePowerProvider            = StreamProvider<int>(...);
final liveCadenceProvider          = StreamProvider<int>(...);
final liveHeartRateProvider        = StreamProvider<int>(...);
final trainerConnectionProvider    = StreamProvider<BluetoothConnectionState>(...);
```

---

## `DeviceInfo` model

```dart
enum DeviceType { trainer, heartRate, cadence }

class DeviceInfo {
  final String id;    // BLE device id
  final String name;
  final DeviceType type;
}
```

Persisted as JSON in `shared_preferences` under `paired_devices`.

---

## Device Setup view

Two sections:

1. **Paired Devices** — list of saved `DeviceInfo` entries.  
   - Each row: device name, type chip, connection status dot, Forget button.
   - "Connect All" button that calls `connect()` on each service.

2. **Add Device** — one button per type ("Add Trainer", "Add HR Monitor", "Add Cadence Sensor").  
   - Opens `DeviceScanSheet`: scans filtered by the relevant service UUID.  
   - Tap a result → connects, saves `DeviceInfo`, dismisses sheet.

---

## Navigation

No new nav entry. The BLE pairing UI lives as a new expandable sub-section at the bottom of `SetupView` ("Devices"), consistent with `views.md`. `AppView` enum and `app_shell.dart` are unchanged.

---

## Auto-reconnect strategy

Each service holds a `_reconnectLoop()` that:
1. Listens for `DeviceDisconnected` events.
2. Waits 2 s, then retries `connect()` with exponential back-off (max 30 s).
3. Stops when `disconnect()` is called explicitly.

---

## `pubspec.yaml` additions

```yaml
dependencies:
  flutter_blue_plus: ^1.31.0   # BLE
```

Windows also needs `manifest` permissions (BLE is already allowed on Windows 11 without a special manifest entry, but double-check with a real device).

---

## Implementation order

1. Add `flutter_blue_plus` dep.
2. ~~`DeviceInfo` model~~ — already implemented (`lib/models/device_info.dart`). Add persistence helper only.
3. `BleScanner` as Riverpod `Provider<BleScanner>`.
4. `TrainerService` (connect, notify parse, ERG write, reconnect).
5. `HrService` (connect, parse, reconnect).
6. `CadenceService` (optional — only if FE-C cadence field is zero on real hardware).
7. Riverpod providers wiring everything together.
8. `DeviceScanSheet` bottom sheet (opened from SetupView).
9. Device pairing sub-section inside `SetupView`.
10. Smoke test: connect, read live data, send ERG command.

---

## Out of scope for Phase 3

- Cadence sensor (separate BLE CSC device) — implement only if trainer FE-C cadence field is consistently zero on real hardware.
- Strava OAuth, sqflite, Claude API — later phases.
