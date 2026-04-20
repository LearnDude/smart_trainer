# Phase 6 — Post-Session View

## Goal

Build the Post-Session view that appears after a workout completes (or is stopped early). The view shows a session summary, collects an RPE rating and optional notes, saves the result to sqflite, and offers Strava export.

---

## Scope

1. `SessionResult` model
2. Database: new `session_results` table + service methods
3. `sessionHistoryProvider` Riverpod provider
4. TSS computation helper
5. `PostSessionView` UI
6. Strava OAuth + TCX upload service

---

## Step 1 — `SessionResult` Model (`lib/models/session_result.dart`)

```dart
class SessionResult {
  final int? id;
  final DateTime date;
  final String workoutName;
  final int durationSeconds;
  final int avgPower;
  final int avgHr;
  final double tss;
  final List<int> powerSamples;
  final List<int> hrSamples;
  final String workoutJson;        // original Workout serialized
  final int rpeRating;             // 1–5 (Easy → Maximum Effort)
  final String notes;              // may be empty
}
```

`rpeRating` and `notes` are written at save time (after user submits survey).

---

## Step 2 — TSS Computation

TSS = (duration_seconds / 3600) × IF² × 100  
where IF = NP / FTP and NP = normalized power.

**Normalized Power** from the `powerSamples` list:
1. Compute a 30-second rolling average of power (ignore zeros for warm-up grace).
2. Raise each rolling average value to the 4th power.
3. Take the mean, then the 4th root.

Add `computeNP(List<int> powerSamples)` and `computeTSS(int durationSec, double np, int ftp)` as top-level functions in a new `lib/utils/training_math.dart` file.

---

## Step 3 — Database (`lib/services/database_service.dart`)

Add a third table in `_onCreate` (version bump to 2, add `_onUpgrade`):

```sql
CREATE TABLE session_results (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  date         TEXT    NOT NULL,
  workout_name TEXT    NOT NULL,
  duration_sec INTEGER NOT NULL,
  avg_power    INTEGER NOT NULL,
  avg_hr       INTEGER NOT NULL,
  tss          REAL    NOT NULL,
  power_samples TEXT   NOT NULL,   -- JSON array
  hr_samples    TEXT   NOT NULL,   -- JSON array
  workout_json  TEXT   NOT NULL,
  rpe_rating   INTEGER NOT NULL,
  notes        TEXT    NOT NULL DEFAULT '',
  created_at   TEXT    NOT NULL
)
```

Add to `DatabaseService`:
- `insertSessionResult(SessionResult r) → Future<int>`
- `queryAllSessionResults() → Future<List<SessionResult>>`
- `querySessionResult(int id) → Future<SessionResult?>`

---

## Step 4 — Riverpod Provider (`lib/providers/session_history_provider.dart`)

```dart
final sessionHistoryProvider =
    AsyncNotifierProvider<SessionHistoryNotifier, List<SessionResult>>(
        SessionHistoryNotifier.new);
```

Methods:
- `save(SessionResult r) → Future<void>` — inserts and refreshes list
- `load() → Future<void>` — queries all (called by build)

---

## Step 5 — Strava Service (`lib/services/strava_service.dart`)

### OAuth flow (Windows)

1. Spin up a temporary `HttpServer` on `localhost:0` (OS-assigned port).
2. Open the Strava authorization URL in the system browser via `url_launcher`.
3. Wait for the redirect to `http://localhost:{port}/callback?code=...`.
4. Shut down the server; exchange the code for tokens using `dio`.
5. Store `access_token`, `refresh_token`, `expires_at` in `SharedPreferences`.
6. On subsequent calls check expiry and refresh if needed.

Strava app credentials (client ID + client secret) are stored via `ApiKeyService` using the same pattern as the Claude key — prompted on first use, stored in `flutter_secure_storage` or `shared_preferences`.

### TCX export

Generate a minimal TCX file from `SessionResult`:
- One `<Activity Sport="Biking">` element
- One trackpoint per second: timestamp, watts (`<Watts>`), HR (`<HeartRateBpm>`)
- `<TotalTimeSeconds>`, `<DistanceMeters>` (estimate from power using w/kg or just 0)

Build the TCX string in Dart (no library needed — it's straightforward XML).

### Upload

`POST https://www.strava.com/api/v3/uploads` with multipart form:
- `data_type: tcx`
- `file: <TCX bytes>`
- `name: <workout name>`
- Bearer token in header

Poll `GET /uploads/{uploadId}` until `status != "processing"` (max ~10 s).

---

## Step 6 — `PostSessionView` UI

**Layout** (single-scroll column, ~400 px wide centered):

```
┌──────────────────────────────┐
│  Workout Complete             │  ← or "Workout Stopped" if partial
│                              │
│  [Workout Name]              │
│  Duration  Avg Power  Avg HR │
│  TSS                         │
│                              │
│  How did this feel?          │
│  ○ Easy                      │
│  ○ Moderate                  │
│  ○ Hard                      │
│  ○ Very Hard                 │
│  ○ Maximum Effort            │
│                              │
│  Notes (optional)            │
│  [TextField]                 │
│                              │
│  [Save]   [Export to Strava] │
│           [Skip]             │
└──────────────────────────────┘
```

**State**:
- Read `executionProvider` for raw session data.
- `selectedRpe` local state (null until user picks one).
- `Save` disabled until RPE selected.
- `Export to Strava` also saves first if not yet saved.
- After save → navigate to `calendar` (or `planner`); call `ref.read(executionProvider.notifier).reset()`.

**Partial session handling**: if `totalElapsedSeconds < 60`, show "This session was less than 1 minute — save anyway?" with confirm/discard choice.

---

## Step 7 — Strava Credentials Setup

Add Strava Client ID and Client Secret fields to `SetupView` under a new "Strava" section (below device pairing link). Store alongside FTP settings. Show only a masked display once set; offer "Clear" button.

Alternatively, prompt inline on first "Export to Strava" tap (simpler — avoids adding Setup view fields). **Use inline prompt for Phase 6 to keep scope tight.**

---

## Files to create

| File | Purpose |
|---|---|
| `lib/models/session_result.dart` | SessionResult model + JSON serialization |
| `lib/utils/training_math.dart` | computeNP, computeTSS |
| `lib/services/strava_service.dart` | OAuth, TCX generation, upload |
| `lib/providers/session_history_provider.dart` | Riverpod notifier over session_results table |

## Files to modify

| File | Change |
|---|---|
| `lib/services/database_service.dart` | Add session_results table (version 2, _onUpgrade), insert/query methods |
| `lib/views/post_session/post_session_view.dart` | Full implementation replacing stub |
| `pubspec.yaml` | Add `url_launcher` for Strava browser OAuth |

---

## New pubspec dependency

```yaml
url_launcher: ^6.3.1
```

Already present: `dio`, `shared_preferences`, `sqflite`.

---

## Out of scope for Phase 6

- Power / HR chart replay on Post-Session screen (Phase 7 / Calendar tap can show this)
- Strava segment matching or kudos
- Email export
- Training load / fitness chart (future)
