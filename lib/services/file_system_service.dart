import 'dart:io';

import 'package:file_picker/file_picker.dart';

class FileSystemService {
  Future<Directory> pickProjectDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку',
    );
    if (path == null) {
      throw const FilePickerCancelledException();
    }
    return Directory(path);
  }

  Future<List<FileSystemEntity>> listDirectory(Directory directory) {
    return directory.list(followLinks: false).toList();
  }

  Future<String> readFile(File file) => file.readAsString();

  Future<void> writeFile(File file, String content) async {
    await file.writeAsString(content);
  }

  Future<File> createFile(Directory directory, String name) async {
    return File(
      directory.path + Platform.pathSeparator + name,
    ).create();
  }

  Future<Directory> createDirectory(Directory parent, String name) async {
    return Directory(
      parent.path + Platform.pathSeparator + name,
    ).create();
  }

  Future<FileSystemEntity> rename(
    FileSystemEntity entity,
    String newName,
  ) async {
    final parent = entity.parent.path;
    final target = parent + Platform.pathSeparator + newName;
    return entity.rename(target);
  }

  Future<void> delete(FileSystemEntity entity) {
    return entity.delete(recursive: true);
  }

  Future<FileSystemEntity> copyOrMove(
    FileSystemEntity entity,
    Directory destination, {
    required bool move,
  }) async {
    final targetPath =
        destination.path + Platform.pathSeparator + _name(entity);

    if (move) {
      return entity.rename(targetPath);
    }

    if (entity is File) {
      return entity.copy(targetPath);
    }

    if (entity is Directory) {
      final target = Directory(targetPath);
      await _copyDirectory(entity, target);
      return target;
    }

    throw UnsupportedError('Неподдерживаемый тип файла');
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final child in source.list(followLinks: false)) {
      final childTarget =
          target.path + Platform.pathSeparator + _name(child);
      if (child is Directory) {
        await _copyDirectory(child, Directory(childTarget));
      } else if (child is File) {
        await child.copy(childTarget);
      }
    }
  }

  String _name(FileSystemEntity entity) {
    final normalized = entity.path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? entity.path : parts.last;
  }
}

class FilePickerCancelledException implements Exception {
  const FilePickerCancelledException();
}