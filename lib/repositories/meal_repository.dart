import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/errors/app_exception.dart';
import '../models/meal.dart';
import '../models/traffic_light.dart';
import '../services/storage/local_database.dart';
import '../services/storage/photo_storage.dart';

class MealRepository {
  const MealRepository(this._database, this._photos);

  final LocalDatabase _database;
  final PhotoStorage _photos;

  Database get _db => _database.db;

  Future<List<Meal>> all() async {
    final rows = await _db.query(LocalDatabase.mealsTable, orderBy: 'created_at DESC');
    return rows.map(_fromRow).whereType<Meal>().toList();
  }

  Future<void> save(Meal meal) async {
    try {
      await _db.insert(LocalDatabase.mealsTable, _toRow(meal), conflictAlgorithm: ConflictAlgorithm.replace);
    } on DatabaseException {
      throw const StorageException();
    }
  }

  Future<void> markSynced(String id) =>
      _db.update(LocalDatabase.mealsTable, {'synced': 1}, where: 'id = ?', whereArgs: [id]);

  Future<void> delete(Meal meal) async {
    await _db.delete(LocalDatabase.mealsTable, where: 'id = ?', whereArgs: [meal.id]);
    await _photos.delete(meal.photoPath);
  }

  Future<void> deleteAll() async {
    await _db.delete(LocalDatabase.mealsTable);
    await _photos.deleteAll();
  }

  Map<String, Object?> _toRow(Meal meal) => {
        'id': meal.id,
        'created_at': meal.createdAt.millisecondsSinceEpoch,
        'meal_type': meal.mealType.name,
        'name': meal.name,
        'photo_path': meal.photoPath,
        'source': meal.source.name,
        'traffic_light': meal.trafficLight.name,
        'score': meal.score,
        'foods_json': jsonEncode(meal.foods.map((item) => item.toJson()).toList()),
        'synced': meal.synced ? 1 : 0,
      };

  /// Devuelve null si una fila está corrupta, para no bloquear el historial.
  Meal? _fromRow(Map<String, Object?> row) {
    try {
      final foods = (jsonDecode(row['foods_json'] as String) as List)
          .map((item) => MealFood.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      return Meal(
        id: row['id'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        mealType: MealType.fromName(row['meal_type'] as String?),
        name: row['name'] as String,
        photoPath: row['photo_path'] as String?,
        source: MealSource.values.firstWhere((s) => s.name == row['source'], orElse: () => MealSource.search),
        trafficLight: TrafficLight.fromName(row['traffic_light'] as String?),
        score: row['score'] as int,
        foods: foods,
        synced: row['synced'] == 1,
      );
    } catch (_) {
      return null;
    }
  }
}
