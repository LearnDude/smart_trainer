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
