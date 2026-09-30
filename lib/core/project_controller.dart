import 'dart:io';

import '../services/file_system_service.dart';

class ProjectController {
  ProjectController({FileSystemService? fileSystem})
      : fileSystem = fileSystem ?? FileSystemService();

  final FileSystemService fileSystem;

  Directory? _projectDirectory;

  Directory? get projectDirectory => _projectDirectory;

  bool get hasProject => _projectDirectory != null;

  Future<void> openProject(Directory directory) async {
    _projectDirectory = directory;
  }

  Future<List<FileSystemEntity>> listProjectFiles() async {
    final directory = _projectDirectory;
    if (directory == null) return [];
    return fileSystem.listDirectory(directory);
  }

  Future<String> read(File file) => fileSystem.readFile(file);

  Future<void> save(File file, String content) {
    return fileSystem.writeFile(file, content);
  }

  Future<File> createFile(String name) {
    final directory = _projectDirectory;
    if (directory == null) {
      throw StateError('Проект не открыт');
    }
    return fileSystem.createFile(directory, name);
  }

  Future<Directory> createDirectory(String name) {
    final directory = _projectDirectory;
    if (directory == null) {
      throw StateError('Проект не открыт');
    }
    return fileSystem.createDirectory(directory, name);
  }

  Future<FileSystemEntity> rename(FileSystemEntity entity, String newName) {
    return fileSystem.rename(entity, newName);
  }

  Future<void> delete(FileSystemEntity entity) {
    return fileSystem.delete(entity);
  }
}
