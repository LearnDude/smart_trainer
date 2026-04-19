# Smart Trainer App — Implementation Plan

## Tech Stack

| Concern | Choice | Reason |
|---|---|---|
| UI framework | Flutter (Windows first) | Single codebase, best BLE+charting ecosystem |
| BLE | `flutter_blue_plus` | Mature, cross-platform |
| Charts | `fl_chart` | Real-time capable, highly customizable |
| State | Riverpod | Reactive streams suit live BLE data well |
| LLM | Claude API (`claude-sonnet-4-6`) | User preference; streaming responses |
| HTTP | `dio` | Strava OAuth + Claude API calls |
| Local storage | `shared_preferences` + `sqflite` | Settings + workout history |
| Strava export | Strava API v3 (FIT file upload) | Standard export path |
| Strava OAuth | System browser redirect | Better UX than embedded WebView |

---

## Trainer BLE Protocol — TacX Flux

The Flux does **not** support FTMS. It uses a proprietary Bluetooth LE service — no ANT+ hardware required. The packet format inside that BLE service follows the FE-C specification, but the transport is entirely BLE and works on Windows, Android, and iOS.

- BLE service UUID: `6e40fec1-b5a3-f393-e0a9-e50e24dcca9e` (Tacx FE-C over BLE)
- Write characteristic: `6e40fec2-...` (send FE-C commands)
- Notify characteristic: `6e40fec3-...` (receive power/cadence/speed data)
- Reference implementations: [tacx-ios-bluetooth-example](https://github.com/abellono/tacx-ios-bluetooth-example), [pycycling](https://pypi.org/project/pycycling/)

FE-C command to set target power (ERG mode): page 49 (`0x31`) with target watts as a 16-bit little-endian value.

---

## Workout Format (Internal DSL)

```dart
sealed class WorkoutStep {}

class SteadyState extends WorkoutStep {
  final Duration duration;
  final PowerTarget power; // watts or % FTP
}

class Interval extends WorkoutStep {
  final int reps;
  final SteadyState on;
  final SteadyState off;
}

class Ramp extends WorkoutStep {
  final Duration duration;
  final PowerTarget from;
  final PowerTarget to;
}
```

The LLM translates natural language → JSON matching this schema → parsed into Dart objects.

---

## Post-Session Survey (TrainerRoad style)

Single question: **"How did this workout feel?"**

| Option | Description |
|---|---|
| Easy | Non-taxing, little effort or focus required. Could repeat it. |
| Moderate | Mostly comfortable, required some focus. Could comfortably repeat the last set. |
| Hard | Challenging, required real effort and focus to complete. |
| Very Hard | Pushed well beyond comfortable limits. |
| Maximum Effort | Extreme difficulty. Barely made it through. |

---

## Views (8 total)

1. **Setup** — FTP, VT1, VT2, max HR, custom zones
2. **Workout Planner** — two modes: (a) single workout via NLP → preview → start/schedule; (b) multi-week training plan via NLP → week-by-week preview → schedule all to calendar
3. **Workout Editor** — fine-tune a generated or loaded workout step-by-step before executing or saving
4. **Workout Execution** — compact live view with real-time chart
5. **Post-Session** — survey + Strava export
6. **Calendar** — workout history (past) + scheduled workouts (future); NLP scheduling interface
7. **Library** — saved/named workouts for re-use, click to load into planner or editor
8. **Device Setup** — BLE pairing for trainer, HR monitor, cadence sensor (split from Setup for clarity)

---

## Phases

### Phase 1 — Project Scaffold
- Flutter project, Windows target
- Folder structure: `lib/services/`, `lib/models/`, `lib/views/`, `lib/providers/`
- Riverpod setup
- Navigation shell (side rail) with placeholder screens for all 6 views

### Phase 2 — Setup View
- Form: FTP, VT1, VT2, Max HR
- Optional custom power zones and HR zones
- Persisted via `shared_preferences`
- Validates FTP > 0 before other views are usable

### Phase 3 — BLE / Trainer Service
- Scan and connect to Tacx FE-C BLE service
- Subscribe to notify characteristic for live power + cadence
- Send ERG target power commands via write characteristic
- Connect to **heart rate monitor** via standard BLE Heart Rate Service (UUID `0x180D`, characteristic `0x2A37`)
- Connect to **cadence sensor** via BLE Cycling Speed and Cadence Service (UUID `0x1816`, characteristic `0x2A5B`) — or read cadence from trainer FE-C data if the sensor is integrated
- `TrainerService` Riverpod provider exposes streams: `power`, `cadence`, `heartRate`, `connectionState`
- Auto-reconnect on disconnect for all three devices
- Setup view includes a device pairing screen to scan and save the BLE addresses of trainer, HR monitor, and cadence sensor

### Phase 4 — Workout Planning View

The Planner handles two distinct modes, selectable by the user:

#### Single Workout Mode
- Text input + "Generate" button
- Claude API call with system prompt defining the workout JSON schema
- Stream response; parse JSON on completion
- Render workout as visual block list (watts + duration)
- "Edit Workout", "Save to Library", "Start Workout", and "Schedule" buttons
- "Schedule" → date picker → saves as a planned entry in `sqflite`

#### Training Plan Mode
- Text input for multi-week goals, e.g. "four-week aerobic base building phase" or "six weeks to increase my FTP"
- Claude receives: goal, available days per week (asked if not stated in the prompt), and today's date
- Returns a structured training plan: an ordered list of weeks, each containing named workout entries assigned to specific days
- Each workout entry in the plan uses the same `Workout` JSON schema (so they are immediately executable)
- Plan is rendered as a week-by-week overview: week number, goal/focus label, list of workouts with day, name, duration, and intensity summary
- "Schedule All" — bulk-writes every workout to `planned_workouts` in `sqflite` on the correct dates, populating the Calendar
- Individual workouts in the plan can be tapped to preview, edit, or reschedule before committing
- "Save Plan" — stores the whole plan as a named entity in a `training_plans` table for reference

**Claude system prompt for plan mode** must include:
- Today's date (so Claude assigns absolute calendar dates to each workout)
- User's FTP, VT1, VT2, and max HR read from `settingsProvider` — injected into the system prompt so intensity targets come back as real watts, not vague % FTP descriptions
- The workout JSON schema and the constraint that every workout must be parseable by the app
- Instruction to respect the progressive overload principle and include rest/recovery days

### Phase 4b — Workout Editor View
- Editable list of workout steps (add, remove, reorder)
- Each step: type selector (SteadyState / Interval / Ramp), duration, power target (watts or % FTP)
- Interval block: reps + on/off sub-steps inline
- Live preview updates as edits are made (same visual block format as Planner)
- Accessed from Planner ("Edit Workout") or Library (tap → edit)
- "Save to Library" and "Start Workout" buttons

### Phase 5 — Workout Execution View
- Compact layout (designed to share screen space)
- Header: elapsed / remaining time, target watts, actual watts, HR, cadence
- Chart: full-session power profile (planned grey, actual color), live scrolling
- ERG commands sent on step transitions
- State machine: idle → countdown → active → complete
- Pause / stop controls
- On complete: navigate to Post-Session

### Phase 6 — Post-Session View
- 5-option survey (Easy → Maximum Effort)
- Optional free-text notes
- Summary stats: avg power, avg HR, duration, TSS
- "Export to Strava" — system browser OAuth if needed, then FIT upload
- Workout saved to `sqflite`

### Phase 7 — Calendar View
- Month grid view showing both completed workouts (past) and planned workouts (future)
  - Past days: colored dot → tap → summary card (duration, avg power, survey response)
  - Future days: outlined dot → tap → planned workout card with "Edit" and "Start" shortcuts
- NLP scheduling interface: text input ("easy 45 min zone 2 on Thursday") → Claude generates workout → saved as planned entry for that date
  - Claude resolves relative dates ("Thursday", "next week") to absolute dates
  - Generated workout flows through the same JSON schema as the Planner view
- Planned entries stored in `sqflite` with a `planned_workouts` table (date, workout JSON, name)
- Data from `sqflite`

### Phase 8 — Library View
- List of saved named workouts
- Each shows: name, total duration, description
- Tap to load into Planner view
- Swipe/button to delete

### Phase 9 — Polish
- Responsive layout prep for mobile screen sizes
- Dark mode
- Error states: trainer disconnect mid-workout, API timeout, Strava failure
