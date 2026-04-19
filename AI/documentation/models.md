# Data Models

All models live in `smart_trainer/lib/models/` and are `@immutable`.

---

## UserSettings — `models/user_settings.dart`

Stores the user's physiological metrics and optional custom zones. Persisted via `shared_preferences` through `SettingsNotifier`.

### Fields

| Field | Type | Notes |
|---|---|---|
| `ftp` | `int` | Functional Threshold Power in watts. Required — app is locked until > 0. |
| `vt1` | `int` | First ventilatory threshold (watts). Optional (0 = not set). |
| `vt2` | `int` | Second ventilatory threshold (watts). Optional (0 = not set). |
| `maxHr` | `int` | Max heart rate (bpm). Optional (0 = not set). |
| `customPowerZones` | `List<int>?` | 6 upper bounds in watts for power zones 1–6. Zone 7 is open-ended. Null = use FTP-based Coggan defaults. |
| `customHrZones` | `List<int>?` | 4 upper bounds in bpm for HR zones 1–4. Zone 5 is open-ended. Null = use max-HR-based defaults. |

### Computed Properties

**`powerZoneUpperBounds`** — returns `customPowerZones` if set, otherwise computes Coggan 7-zone model from FTP:

| Zone | Label | Default upper bound |
|---|---|---|
| Z1 | Active Recovery | FTP × 0.55 |
| Z2 | Endurance | FTP × 0.75 |
| Z3 | Tempo | FTP × 0.90 |
| Z4 | Lactate Threshold | FTP × 1.05 |
| Z5 | VO2 Max | FTP × 1.20 |
| Z6 | Anaerobic Capacity | FTP × 1.50 |
| Z7 | Neuromuscular | open-ended |

**`hrZoneUpperBounds`** — returns `customHrZones` if set, otherwise 5-zone model from max HR:

| Zone | Label | Default upper bound |
|---|---|---|
| Z1 | Recovery | maxHR × 0.60 |
| Z2 | Aerobic | maxHR × 0.70 |
| Z3 | Tempo | maxHR × 0.80 |
| Z4 | Threshold | maxHR × 0.90 |
| Z5 | VO2 Max / Anaerobic | open-ended |

**`isConfigured`** — `true` when `ftp > 0`. Gates navigation to all other views.

### Serialization

`toJson()` / `fromJson()` for `shared_preferences` storage. `customPowerZones` and `customHrZones` are omitted from JSON when null.

---

## Workout — `models/workout.dart`

Internal DSL for structured workouts. Used by the Planner, Editor, Execution, and Library views.

### WorkoutStep (sealed class)

Three concrete subtypes:

#### SteadyState
A fixed-power block for a fixed duration.
```dart
SteadyState({required Duration duration, required PowerTarget power})
```

#### IntervalBlock
Repeated on/off pairs.
```dart
IntervalBlock({required int reps, required SteadyState on, required SteadyState off})
```

#### Ramp
Power transitions linearly from `from` to `to` over `duration`.
```dart
Ramp({required Duration duration, required PowerTarget from, required PowerTarget to})
```

### PowerTarget (sealed class)

Two subtypes:

| Type | Description |
|---|---|
| `WattsTarget(int watts)` | Absolute watt value |
| `FtpPercentTarget(double percent)` | Relative to FTP; call `.toWatts(ftp)` to resolve |

### Workout
```dart
Workout({required String name, required List<WorkoutStep> steps})
```
`totalDuration` computed property sums all steps including interval repetitions.

### JSON Schema (for Claude API)

Claude generates workouts as JSON matching this structure. The app parses the JSON into these Dart objects before rendering or executing.

```json
{
  "name": "Over-Under 60",
  "steps": [
    { "type": "steady", "duration_s": 600, "power_w": 150 },
    {
      "type": "interval",
      "reps": 3,
      "on":  { "duration_s": 240, "power_w": 280 },
      "off": { "duration_s": 120, "power_w": 200 }
    },
    { "type": "ramp", "duration_s": 300, "from_w": 200, "to_w": 100 }
  ]
}
```

Power can also be expressed as `"power_pct": 0.95` (% FTP) in place of `"power_w"`.
