import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos SQLite local. Funciona sin conexión; Supabase es opcional.
class LocalDatabase {
  LocalDatabase._(this.db);

  final Database db;

  static const mealsTable = 'meals';

  static Future<LocalDatabase> open() async {
    final path = p.join(await getDatabasesPath(), 'nutrisemaforo.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $mealsTable (
            id TEXT PRIMARY KEY,
            created_at INTEGER NOT NULL,
            meal_type TEXT NOT NULL,
            name TEXT NOT NULL,
            photo_path TEXT,
            source TEXT NOT NULL,
            traffic_light TEXT NOT NULL,
            score INTEGER NOT NULL,
            foods_json TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_meals_created_at ON $mealsTable (created_at DESC)');
      },
    );
    return LocalDatabase._(db);
  }
}
