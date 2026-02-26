import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/court_case.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'court_monitoring.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE cases ADD COLUMN custom_alert_sent INTEGER DEFAULT 0');
        }
      },
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cases(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        advocate_name TEXT,
        court_no TEXT,
        case_number TEXT,
        item_no TEXT,
        alert_at TEXT,
        alert_sent INTEGER DEFAULT 0,
        custom_alert_sent INTEGER DEFAULT 0
      )
    ''');
  }

  Future<int> insertCase(CourtCase courtCase) async {
    Database db = await database;
    return await db.insert('cases', courtCase.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CourtCase>> getCases() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cases');
    return List.generate(maps.length, (i) {
      return CourtCase.fromMap(maps[i]);
    });
  }

  Future<int> updateCase(CourtCase courtCase) async {
    Database db = await database;
    return await db.update(
      'cases',
      courtCase.toMap(),
      where: 'id = ?',
      whereArgs: [courtCase.id],
    );
  }

  Future<int> deleteCase(int id) async {
    Database db = await database;
    return await db.delete(
      'cases',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllCases() async {
    Database db = await database;
    return await db.delete('cases');
  }
}
