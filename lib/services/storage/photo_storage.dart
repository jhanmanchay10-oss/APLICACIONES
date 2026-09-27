import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/app_exception.dart';

/// Guarda las fotos dentro del almacenamiento privado de la aplicación.
class PhotoStorage {
  const PhotoStorage();

  Future<Directory> _directory(String folder) async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, folder));
    if (!directory.existsSync()) await directory.create(recursive: true);
    return directory;
  }

  Future<String> saveMealPhoto(File source, String mealId) => _copy(source, 'meal_photos', mealId);

  Future<String> saveAvatar(File source) =>
      _copy(source, 'profile', 'avatar_${DateTime.now().millisecondsSinceEpoch}');

  Future<String> _copy(File source, String folder, String name) async {
    try {
      final directory = await _directory(folder);
      final extension = p.extension(source.path).isEmpty ? '.jpg' : p.extension(source.path);
      final target = await source.copy(p.join(directory.path, '$name$extension'));
      return target.path;
    } on FileSystemException {
      throw const StorageException('No pudimos guardar la foto en tu dispositivo.');
    }
  }

  Future<void> delete(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }

  Future<void> deleteAll() async {
    for (final folder in ['meal_photos', 'profile']) {
      final directory = await _directory(folder);
      if (directory.existsSync()) await directory.delete(recursive: true);
    }
  }
}
