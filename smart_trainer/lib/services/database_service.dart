import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/session_result.dart';
import '../models/workout.dart';

class DatabaseService {
  static const _dbName = 'smart_trainer.db';
  static const _version = 2;

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, _) async {
        await _createAll(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createSessionResultsTable(db);
        }
      },
    );
  }

  Future<void> _createAll(Database db) async {
    await db.execute('''
      CREATE TABLE planned_workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        name TEXT NOT NULL,
        workout_json TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE library_workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        workout_json TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await _createSessionResultsTable(db);
  }

  Future<void> _createSessionResultsTable(Database db) async {
    await db.execute('''
      CREATE TABLE session_results (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        date         TEXT    NOT NULL,
        workout_name TEXT    NOT NULL,
        duration_sec INTEGER NOT NULL,
        avg_power    INTEGER NOT NULL,
        avg_hr       INTEGER NOT NULL,
        tss          REAL    NOT NULL,
        power_samples TEXT   NOT NULL,
        hr_samples    TEXT   NOT NULL,
        workout_json  TEXT   NOT NULL,
        rpe_rating   INTEGER NOT NULL,
        notes        TEXT    NOT NULL DEFAULT '',
        created_at   TEXT    NOT NULL
      )
    ''');
  }

  // ── planned_workouts ──────────────────────────────────────────────────────

  Future<void> insertPlannedWorkout(DateTime date, Workout workout) async {
    final db = await _database;
    await db.insert('planned_workouts', {
      'date': date.toIso8601String().substring(0, 10),
      'name': workout.name,
      'workout_json': workout.toJsonString(),
    });
  }

  // ── library_workouts ──────────────────────────────────────────────────────

  Future<void> insertLibraryWorkout(Workout workout,
      {String? description}) async {
    final db = await _database;
    await db.insert('library_workouts', {
      'name': workout.name,
      'workout_json': workout.toJsonString(),
      'description': description,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ── session_results ───────────────────────────────────────────────────────

  Future<int> insertSessionResult(SessionResult result) async {
    final db = await _database;
    return db.insert('session_results', result.toMap());
  }

  Future<List<SessionResult>> queryAllSessionResults() async {
    final db = await _database;
    final rows = await db.query('session_results', orderBy: 'date DESC');
    return rows.map(SessionResult.fromMap).toList();
  }

  Future<SessionResult?> querySessionResult(int id) async {
    final db = await _database;
    final rows = await db.query('session_results',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : SessionResult.fromMap(rows.first);
  }
}

final databaseServiceProvider = Provider((_) => DatabaseService());
