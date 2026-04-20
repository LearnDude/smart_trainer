
# Build Phases

| Phase | Name | Status |
|---|---|---|
| 1 | Project Scaffold | ✅ Complete |
| 2 | Setup View | ✅ Complete |
| 3 | BLE / Trainer Service | ✅ Complete |
| 4 | Workout Planning View | ✅ Complete |
| 4b | Workout Editor View | ✅ Complete |
| 5 | Workout Execution View | ✅ Complete |
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

## Phase 4 — Workout Planning View ✅

See [views.md](views.md) — Planner section.

### What was built
- `models/training_plan.dart` — `PlannedEntry`, `TrainingPlan` (with `byWeekNumber` grouping)
- `services/api_key_service.dart` — reads/writes Claude API key to `%APPDATA%\smart_trainer\api_key` via `path_provider`
- `services/database_service.dart` — SQLite (via `sqflite_common_ffi` FFI on Windows) with `planned_workouts` and `library_workouts` tables
- `services/claude_service.dart` — `dio`-based Claude API; single workout and training plan modes; strips markdown code fences from responses
- `providers/planner_provider.dart` — `PlannerState` + `PlannerNotifier`; mode toggle, generate, schedule, save to library
- `views/setup/setup_view.dart` — API key field added (show/hide toggle, saved alongside other settings)
- `views/planner/planner_view.dart` — full UI: mode toggle, NLP prompt input, block chart (`CustomPainter`, zone-coloured), step list, Schedule date picker, Save to Library, Edit (stub → Phase 4b), Start (stub → Phase 5)
- `workout.dart` — `fromJson`/`toJson` added to all model classes

### Dependency notes
- `flutter_secure_storage` was evaluated but requires Visual Studio ATL which is not installed. Key stored in plain file in user AppData instead. Install ATL later to upgrade.
- `sqflite_common_ffi` initialised in `main.dart` before `runApp`.

## Phase 4b — Workout Editor View ✅

- Editable step list (add, remove, reorder)
- Step type selector: SteadyState / Interval / Ramp
- Inline interval sub-step editing
- Live preview updates in real time
- Accessed from Planner ("Edit Workout") or Library

## Phase 5 — Workout Execution View ✅

### What was built
- `models/flat_step.dart` — `FlatStep` (steady + ramp variants), `flattenWorkout(Workout, int ftp)` expands `IntervalBlock` into on/off pairs and resolves all `PowerTarget` to absolute watts
- `providers/execution_provider.dart` — `ExecutionState` + `ExecutionNotifier`; state machine `idle → active → paused → complete`; `Timer.periodic` tick samples live power/HR from BLE stream providers, advances step index, sends ERG commands via `TrainerService.setTargetPower`; ramp steps re-send ERG every second
- `widgets/execution_chart.dart` — `CustomPainter`; planned profile as dark-grey filled blocks (trapezoid for ramps), FTP reference dashed line, actual power as orange polyline, cursor as white dashed vertical line; full-session x-axis with cursor advancing left-to-right
- `views/execution/execution_view.dart` — three states: idle placeholder, active/paused workout view (metrics row, chart, step progress bar, pause/resume/stop controls), completing spinner; `ref.listen` auto-navigates to PostSession on complete
- `views/planner/planner_view.dart` — Start button wired: checks trainer connection, calls `executionProvider.notifier.startWorkout`, navigates to Execution view
- `views/editor/editor_view.dart` — Start Workout button wired via `onStart` callback; pops editor route then navigates to Execution view

### Behaviour notes
- Pause drops ERG to 50W; resume restores target watts
- Stop shows confirmation dialog, then navigates to Post-Session with partial data
- Trainer must be connected (BLE) before Start is allowed; shows snackbar otherwise
- `ExecutionState` retains `powerSamples` + `hrSamples` + `avgPower` + `avgHr` after complete for Phase 6 Post-Session to consume

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
