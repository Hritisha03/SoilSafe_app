import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/prediction_result.dart';
import 'dart:convert';

class AssessmentDatabase {
  static const String tableName = 'assessments';
  static Database? _database;

  // Initialize database
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'soilsafe_assessments.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            latitude REAL,
            longitude REAL,
            region TEXT,
            input_json TEXT NOT NULL,
            result_json TEXT NOT NULL,
            risk_level TEXT NOT NULL,
            soil_type TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  // Save assessment to local database
  static Future<int> saveAssessment({
    required double? latitude,
    required double? longitude,
    required String? region,
    required Map<String, dynamic> input,
    required Map<String, dynamic> result,
  }) async {
    final db = await database;
    
    return await db.insert(
      tableName,
      {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'region': region,
        'input_json': jsonEncode(input),
        'result_json': jsonEncode(result),
        'risk_level': result['risk_level'] ?? result['risk'] ?? 'Unknown',
        'soil_type': input['soil_type'],
      },
    );
  }

  // Get all assessments
  static Future<List<Map<String, dynamic>>> getAllAssessments() async {
    final db = await database;
    return await db.query(
      tableName,
      orderBy: 'created_at DESC',
    );
  }

  // Get assessment by ID
  static Future<Map<String, dynamic>?> getAssessmentById(int id) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Get recent assessments (last N)
  static Future<List<Map<String, dynamic>>> getRecentAssessments({int limit = 10}) async {
    final db = await database;
    return await db.query(
      tableName,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  // Search assessments by location
  static Future<List<Map<String, dynamic>>> searchByLocation(
    double latitude,
    double longitude, {
    double radiusKm = 10.0,
  }) async {
    final db = await database;
    // Simple bounding box search (rough approximation)
    final latDelta = radiusKm / 111.0; // 1 degree lat ≈ 111 km
    final lonDelta = radiusKm / 111.0;
    
    return await db.query(
      tableName,
      where: 'latitude IS NOT NULL AND longitude IS NOT NULL AND '
          'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
      whereArgs: [
        latitude - latDelta,
        latitude + latDelta,
        longitude - lonDelta,
        longitude + lonDelta,
      ],
      orderBy: 'created_at DESC',
    );
  }

  // Delete assessment
  static Future<int> deleteAssessment(int id) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Count assessments
  static Future<int> getAssessmentCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Close database (cleanup)
  static Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
