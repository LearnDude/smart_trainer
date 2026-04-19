# Architecture

## Tech Stack

| Concern | Choice |
|---|---|
| UI framework | Flutter (Windows-first, mobile-ready) |
| State management | Riverpod (`flutter_riverpod` + `riverpod_annotation`) |
| BLE | `flutter_blue_plus` |
| Charts | `fl_chart` |
| HTTP / API | `dio` |
| Local storage | `shared_preferences` (settings) + `sqflite` (workouts, history) |
| LLM | Claude API (`claude-sonnet-4-6`) via `dio` |
| Strava export | Strava API v3 — OAuth via system browser, FIT file upload |

## Folder Layout

```
smart_trainer/lib/
├── main.dart                  # App entry point, ProviderScope
├── models/                    # Immutable data classes, no Flutter deps
│   ├── user_settings.dart
│   └── workout.dart
├── providers/                 # Riverpod providers
│   ├── navigation_provider.dart
│   └── settings_provider.dart
├── services/                  # BLE, Claude API, Strava (Phase 3+)
└── views/
    ├── app_shell.dart         # NavigationRail shell
    ├── setup/
    ├── planner/
    ├── execution/
    ├── post_session/
    ├── calendar/
    └── library/
```

## Data Flow

```
User input
    │
    ▼
View (ConsumerStatefulWidget)
    │  ref.watch / ref.read
    ▼
Riverpod Provider
    │  reads/writes
    ▼
Service layer (BLE / API / DB)
    │
    ▼
Model (immutable Dart class)
    │
    ▼
View rebuild via Riverpod stream/state
```

## Key Conventions

- Models are `@immutable` — all mutations return a new instance via `copyWith`.
- Providers are the single source of truth; views never hold persistent state directly.
- `shared_preferences` for user settings (small, keyed values). `sqflite` for structured workout history and planned workouts.
- All Claude API calls go through a dedicated service in `lib/services/`; views never call `dio` directly.
