# Riverpod Providers

All providers live in `smart_trainer/lib/providers/`.

---

## `selectedViewProvider` — `providers/navigation_provider.dart`

```dart
final selectedViewProvider = StateProvider<AppView>((ref) => AppView.planner);
```

Tracks which of the 6 main views is active. `AppShell` watches this and renders the corresponding view. When `UserSettings.isConfigured` is false, `AppShell` ignores this value and forces `AppView.setup`.

**`AppView` enum values (in nav rail order):**
`setup`, `planner`, `execution`, `postSession`, `calendar`, `library`

---

## `settingsProvider` — `providers/settings_provider.dart`

```dart
final settingsProvider = AsyncNotifierProvider<SettingsNotifier, UserSettings>(
  SettingsNotifier.new,
);
```

Async notifier that loads `UserSettings` from `shared_preferences` on first access, and writes back on `save()`.

### SettingsNotifier

| Method | Description |
|---|---|
| `build()` | Reads JSON from `shared_preferences` key `user_settings`. Returns `UserSettings.empty` if not found. |
| `save(UserSettings)` | Updates `state` immediately (optimistic) then writes JSON to `shared_preferences`. |

### Usage in views

```dart
// Read
final settingsAsync = ref.watch(settingsProvider);
final settings = settingsAsync.requireValue; // throws if loading/error

// Write
await ref.read(settingsProvider.notifier).save(newSettings);
```

---

---

## `plannerProvider` — `providers/planner_provider.dart`

```dart
final plannerProvider = NotifierProvider<PlannerNotifier, PlannerState>(PlannerNotifier.new);
```

### PlannerState

| Field | Type | Description |
|---|---|---|
| `mode` | `PlannerMode` | `singleWorkout` or `trainingPlan` |
| `isLoading` | `bool` | True while awaiting Claude API response |
| `workout` | `Workout?` | Generated workout (single workout mode) |
| `plan` | `TrainingPlan?` | Generated plan (training plan mode) |
| `error` | `String?` | User-facing error message |

### PlannerNotifier methods

| Method | Description |
|---|---|
| `setMode(PlannerMode)` | Resets state to idle with new mode |
| `generate(String prompt)` | Reads API key + settings, calls `ClaudeService`, updates state |
| `scheduleWorkout(Workout, DateTime)` | Writes one entry to `planned_workouts` via `DatabaseService` |
| `scheduleAll(TrainingPlan)` | Bulk-writes all plan entries to `planned_workouts` |
| `saveToLibrary(Workout)` | Writes to `library_workouts` via `DatabaseService` |

---

## `apiKeyServiceProvider` — `services/api_key_service.dart`

```dart
final apiKeyServiceProvider = Provider((_) => ApiKeyService());
```

Reads/writes the Claude API key to `%APPDATA%\smart_trainer\api_key` (plain file, user-account-scoped). Methods: `getApiKey()`, `setApiKey(String)`, `deleteApiKey()`.

---

## `databaseServiceProvider` — `services/database_service.dart`

```dart
final databaseServiceProvider = Provider((_) => DatabaseService());
```

Lazy-opens a `sqflite` database at `%APPDATA%\smart_trainer\smart_trainer.db` (via `sqflite_common_ffi` on Windows). Tables: `planned_workouts`, `library_workouts`. Methods: `insertPlannedWorkout`, `insertLibraryWorkout`.

---

## `claudeServiceProvider` — `services/claude_service.dart`

```dart
final claudeServiceProvider = Provider((_) => ClaudeService());
```

`dio`-based client for the Claude API (`claude-sonnet-4-6`). Strips markdown code fences before JSON parsing. Methods: `generateWorkout(...)`, `generateTrainingPlan(...)`.

---

## Planned providers (Phase 3+)

| Provider | Phase | Description |
|---|---|---|
| `trainerConnectionProvider` | 3 | BLE connection state for TacX Flux |
| `livePowerProvider` | 3 | Stream of current power in watts from trainer |
| `liveCadenceProvider` | 3 | Stream of current cadence (rpm) |
| `liveHeartRateProvider` | 3 | Stream of current HR (bpm) from HR monitor |
| `activeWorkoutProvider` | 5 | Current workout state machine (idle/countdown/active/complete) |
| `workoutHistoryProvider` | 6 | Completed workouts from `sqflite` |
| `plannedWorkoutsProvider` | 7 | Planned future workouts from `sqflite` |
| `libraryProvider` | 8 | Saved named workouts from `sqflite` |
