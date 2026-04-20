# Views

All views live in `smart_trainer/lib/views/`. The shell (`app_shell.dart`) hosts them inside a `NavigationRail` layout.

---

## AppShell — `views/app_shell.dart`

`ConsumerWidget` that owns the `NavigationRail` and renders the active view.

**Behaviour:**
- Watches `settingsProvider` and `selectedViewProvider`.
- If `UserSettings.isConfigured` is false: forces `SetupView` in the body, dims all non-Setup rail items, shows a snackbar if the user taps a locked destination.
- If configured: routes to whichever `AppView` is selected.

---

## SetupView — `views/setup/setup_view.dart` ✅ Complete

`ConsumerStatefulWidget`. Populates from `settingsProvider` on first load.

**Form fields:**
- FTP (W) — required, must be > 0
- VT1 (W) — optional; validated < FTP if provided
- VT2 (W) — optional; validated > VT1 if provided
- Max HR (bpm) — optional; sanity-checked ≤ 230

**Expandable sections:**
- *Custom Power Zones* — 6 upper-bound fields (W), pre-filled with Coggan defaults from FTP when expanded
- *Custom HR Zones* — 4 upper-bound fields (bpm), pre-filled from max HR when expanded
- Both sections are optional; collapsing clears the override (defaults resume)

**On save:** writes to `settingsProvider.notifier.save()` → `shared_preferences`. Shows a SnackBar on success. Unlocks the rest of the app once FTP > 0.

**Phase 3 addition:** a device pairing sub-section will be added here for BLE addresses of trainer, HR monitor, and cadence sensor.

---

## PlannerView — `views/planner/planner_view.dart` ✅ Complete

Phase 4. Side-by-side layout: left input panel (340px fixed), right preview panel (expanded).

**Single Workout Mode**
- NLP text input → `PlannerNotifier.generate()` → Claude API → `Workout` → preview panel
- Preview: workout name, total duration, `WorkoutBlockChart` (zone-coloured `CustomPainter`), step list
- Buttons: Edit (stub → Phase 4b), Save to Library (`sqflite`), Start (stub → Phase 5), Schedule (date picker → `sqflite`)

**Training Plan Mode**
- NLP text input for multi-week goals (e.g. "4-week aerobic base")
- Claude receives goal + today's date + FTP/VT1/VT2 from `settingsProvider`
- Preview: plan name, total workout count, week-by-week `ExpansionTile` list with mini block charts
- Buttons: Schedule All (bulk-writes all entries to `sqflite`), Save Plan (stub → Phase 7)

**`WorkoutBlockChart`** — `CustomPainter` widget. Draws proportional-width blocks, height proportional to power vs FTP. Zone colours:

| Zone | % FTP | Colour |
|---|---|---|
| Z1 | < 55% | Blue-grey `#546E7A` |
| Z2 | 55–75% | Blue `#1565C0` |
| Z3 | 75–90% | Green `#2E7D32` |
| Z4 | 90–105% | Amber `#F57F17` |
| Z5 | 105–120% | Orange `#E65100` |
| Z6 | 120–150% | Red `#B71C1C` |
| Z7 | > 150% | Purple `#4A148C` |

Ramps are approximated as 20 equal-width segments graduating in colour.

---

## ExecutionView — `views/execution/execution_view.dart` 🔲 Placeholder

Phase 5. Compact live workout view:
- Header: elapsed / remaining time, target watts, actual watts, HR, cadence
- Full-session power chart (planned = grey, actual = colour), live scrolling
- ERG commands sent to trainer on step transitions
- State machine: idle → countdown → active → complete
- Pause / Stop controls; navigates to PostSessionView on complete

---

## PostSessionView — `views/post_session/post_session_view.dart` 🔲 Placeholder

Phase 6.
- 5-option RPE survey: Easy / Moderate / Hard / Very Hard / Maximum Effort
- Optional free-text notes
- Summary stats: avg power, avg HR, duration, TSS
- Export to Strava (system browser OAuth → FIT file upload)
- Saves completed workout to `sqflite`

---

## CalendarView — `views/calendar/calendar_view.dart` 🔲 Placeholder

Phase 7.
- Month grid — past days show completed workout dots, future days show planned workout dots
- Tap past day → summary card; tap future day → planned workout card (Edit / Start)
- NLP scheduling input: "easy 45 min zone 2 Thursday" → Claude → saved planned entry

---

## LibraryView — `views/library/library_view.dart` 🔲 Placeholder

Phase 8.
- List of saved named workouts (name, total duration, intensity summary)
- Tap → load into Planner or Editor
- Delete action
