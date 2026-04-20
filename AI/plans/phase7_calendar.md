# Phase 7 — Calendar View

## Goal

Month-grid calendar showing completed workouts (past) and planned workouts (future), plus an NLP scheduling interface that generates and saves new planned workouts.

---

## Data sources

| Data | Table | Provider |
|---|---|---|
| Completed sessions | `session_results` | `sessionHistoryProvider` (already exists) |
| Planned workouts | `planned_workouts` | new `plannedWorkoutsProvider` |

Both tables exist in `DatabaseService`. The `planned_workouts` table already has `insertPlannedWorkout()`. Need to add query methods.

---

## New files

```
lib/
  models/
    planned_workout.dart          — PlannedWorkout model (id, date, name, workout_json)
  providers/
    planned_workouts_provider.dart — AsyncNotifier with CRUD
    calendar_provider.dart         — derives CalendarDay list from both providers
  views/
    calendar/
      calendar_view.dart           — replaces placeholder
      widgets/
        month_grid.dart            — 7-column grid
        day_cell.dart              — single calendar cell
        session_detail_sheet.dart  — bottom sheet for past session tap
        planned_detail_sheet.dart  — bottom sheet for future planned tap
        nlp_schedule_bar.dart      — text field + Generate button
```

---

## Models

### `PlannedWorkout`
```dart
class PlannedWorkout {
  final int? id;
  final DateTime date;       // date only, no time
  final String name;
  final String workoutJson;  // Workout.toJsonString()

  Map<String, dynamic> toMap();
  factory PlannedWorkout.fromMap(Map<String, dynamic> m);
}
```

### `CalendarDay` (in-memory, not persisted)
```dart
class CalendarDay {
  final DateTime date;
  final List<SessionResult> sessions;    // past
  final List<PlannedWorkout> planned;    // future
}
```

---

## Providers

### `plannedWorkoutsProvider`
- `AsyncNotifier<List<PlannedWorkout>>`
- Reads all rows from `planned_workouts`
- Methods: `add(PlannedWorkout)`, `delete(int id)`
- Invalidates self after write

### `calendarProvider`
- `Provider<Map<String, CalendarDay>>` — key is `"YYYY-MM-DD"`
- Watches `sessionHistoryProvider` and `plannedWorkoutsProvider`
- Groups entries by date string
- Returns empty map while either is loading

---

## DatabaseService additions (bump to version 3)

```dart
// query all planned workouts
Future<List<PlannedWorkout>> queryAllPlannedWorkouts() async { ... }

// delete a planned workout
Future<void> deletePlannedWorkout(int id) async { ... }
```

`onUpgrade` case: `if (oldVersion < 3)` — nothing to create (table already exists), just bump the constant.

---

## CalendarView layout

```
┌─────────────────────────────────────────────┐
│  < April 2026 >                             │  ← month nav row
├─────────────────────────────────────────────┤
│  Mo  Tu  We  Th  Fr  Sa  Su                │  ← weekday header
│   1   2   3   4   5   6   7                │
│  ...                                        │  ← DayCells
├─────────────────────────────────────────────┤
│  [Schedule a workout…]          [Generate] │  ← NLP bar
└─────────────────────────────────────────────┘
```

### DayCell states
- **Empty past**: plain number, no dot
- **Completed**: filled colored dot (color ← RPE: green 1–2, amber 3, red 4–5)
- **Planned future**: outlined dot, muted color
- **Today**: number has accent background ring
- Multiple entries on same day: stack up to 3 dots, "+N" label if more

### Taps
- Past session tap → `SessionDetailSheet` (bottom sheet): workout name, date, duration, avg power, avg HR, TSS, RPE label, notes
- Planned tap → `PlannedDetailSheet` (bottom sheet): workout name, date, intensity summary, "Start Now" button (navigates to Execution with that workout loaded), "Delete" button

---

## NLP scheduling flow

1. User types in `NlpScheduleBar`, presses Generate
2. Provider calls `ClaudeService.generateWorkout(prompt)` with an augmented system prompt that includes today's date and user FTP/VT1/VT2/maxHR from `settingsProvider`
3. System prompt instructs Claude to resolve relative dates ("Thursday", "next week") to absolute ISO dates and return a `scheduled_date` field alongside the workout JSON
4. On success: `plannedWorkoutsProvider.add(...)`, calendar refreshes, snackbar "Workout scheduled for [date]"

### Claude response schema extension
Add an optional top-level `"scheduled_date": "YYYY-MM-DD"` field to the existing workout JSON. The Planner already uses the same schema — this field is ignored there.

### System prompt additions (NLP bar only)
```
Today is {date}.
The user's FTP is {ftp}W, VT1 {vt1}W, VT2 {vt2}W, max HR {maxHr}bpm.
If the user specifies a date (e.g. "Thursday", "next Monday"), resolve it to an absolute ISO date 
and include "scheduled_date": "YYYY-MM-DD" at the top level of the JSON.
If no date is mentioned, use today's date.
```

---

## Navigation

- `AppView.calendar` already exists in `navigation_provider.dart`
- No changes needed to nav shell

---

## Implementation order

1. `PlannedWorkout` model
2. `DatabaseService` additions (version bump + query/delete methods)
3. `plannedWorkoutsProvider`
4. `calendarProvider`
5. `MonthGrid` + `DayCell` widgets (static, no data yet)
6. Wire up real data (dots appear on grid)
7. `SessionDetailSheet`
8. `PlannedDetailSheet` with Start Now + Delete
9. `NlpScheduleBar` + Claude call + save flow
10. Month navigation (prev/next arrows)
11. Build + manual test

---

## Out of scope for this phase

- Multi-session days with full list view (3-dot cap + "+N" label is sufficient)
- Editing a planned workout from the calendar (use Planner → Editor flow)
- Drag-to-reschedule
- Week view
