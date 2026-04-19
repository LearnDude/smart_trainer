# Build Phases

| Phase | Name | Status |
|---|---|---|
| 1 | Project Scaffold | ✅ Complete |
| 2 | Setup View | ✅ Complete |
| 3 | BLE / Trainer Service | 🔲 Not started |
| 4 | Workout Planning View | 🔲 Not started |
| 4b | Workout Editor View | 🔲 Not started |
| 5 | Workout Execution View | 🔲 Not started |
| 6 | Post-Session View | 🔲 Not started |
| 7 | Calendar View | 🔲 Not started |
| 8 | Library View | 🔲 Not started |
| 9 | Polish | 🔲 Not started |

---

## Phase 1 — Project Scaffold ✅

- Flutter project, Windows target
- Folder structure: `lib/models/`, `lib/providers/`, `lib/services/`, `lib/views/`
- Riverpod `ProviderScope` in `main.dart`
- `NavigationRail` shell (`app_shell.dart`) with placeholder screens for all views
- All dependencies declared in `pubspec.yaml`

## Phase 2 — Setup View ✅

- FTP (required), VT1, VT2, Max HR form with cross-field validation
- Optional custom power zones (6 upper bounds, Coggan 7-zone defaults from FTP)
- Optional custom HR zones (4 upper bounds, 5-zone defaults from max HR)
- Persisted via `shared_preferences` through `SettingsNotifier`
- Navigation guard: all views except Setup are locked until FTP > 0

## Phase 3 — BLE / Trainer Service 🔲

- Scan and connect to TacX Flux via proprietary FE-C over BLE service
  - Service UUID: `6e40fec1-b5a3-f393-e0a9-e50e24dcca9e`
  - Write characteristic: `6e40fec2-...` (ERG commands)
  - Notify characteristic: `6e40fec3-...` (power, cadence, speed)
- Connect to HR monitor via BLE Heart Rate Service (`0x180D`, char `0x2A37`)
- Connect to cadence sensor via BLE CSC Service (`0x1816`, char `0x2A5B`)
- `TrainerService` exposes Riverpod streams: `power`, `cadence`, `heartRate`, `connectionState`
- Auto-reconnect on disconnect
- Device pairing UI added to Setup view (scan + save BLE addresses)

## Phase 4 — Workout Planning View 🔲

See [views.md](views.md) — Planner section.

## Phase 4b — Workout Editor View 🔲

- Editable step list (add, remove, reorder)
- Step type selector: SteadyState / Interval / Ramp
- Inline interval sub-step editing
- Live preview updates in real time
- Accessed from Planner ("Edit Workout") or Library

## Phase 5 — Workout Execution View 🔲

See [views.md](views.md) — Execution section.

## Phase 6 — Post-Session View 🔲

See [views.md](views.md) — Post-Session section.

## Phase 7 — Calendar View 🔲

See [views.md](views.md) — Calendar section.

Requires `sqflite` tables:
- `planned_workouts` (id, date, workout_json, name)
- `completed_workouts` (id, date, workout_json, avg_power, avg_hr, duration_s, tss, rpe, notes)

## Phase 8 — Library View 🔲

See [views.md](views.md) — Library section.

Requires `sqflite` table:
- `library_workouts` (id, name, workout_json, description, created_at)

## Phase 9 — Polish 🔲

- Responsive layout for mobile screen sizes
- Dark mode refinements
- Error states: trainer disconnect mid-workout, Claude API timeout, Strava failure
