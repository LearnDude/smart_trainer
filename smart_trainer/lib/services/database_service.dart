import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/workout.dart';

class DatabaseService {
  static const _dbName = 'smart_trainer.db';
  static const _version = 1;

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, _) async {
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
      },
    );
  }

  Future<void> insertPlannedWorkout(DateTime date, Workout workout) async {
    final db = await _database;
    await db.insert('planned_workouts', {
      'date': date.toIso8601String().substring(0, 10),
      'name': workout.name,
      'workout_json': workout.toJsonString(),
    });
  }

  Future<void> insertLibraryWorkout(Workout workout, {String? description}) async {
    final db = await _database;
    await db.insert('library_workouts', {
      'name': workout.name,
      'workout_json': workout.toJsonString(),
      'description': description,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

final databaseServiceProvider = Provider((_) => DatabaseService());
