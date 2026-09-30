import 'dart:io';

import 'package:file_picker/file_picker.dart';

class FileSystemService {
  Future<Directory> pickProjectDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите проект для PipEdit',
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
    return File(directory.path + Platform.pathSeparator + name).create();
  }

  Future<Directory> createDirectory(Directory parent, String name) async {
    return Directory(parent.path + Platform.pathSeparator + name).create();
  }

  Future<FileSystemEntity> rename(FileSystemEntity entity, String newName) async {
    final parent = entity.parent.path;
    final target = parent + Platform.pathSeparator + newName;
    return entity.rename(target);
  }

  Future<void> delete(FileSystemEntity entity) {
    return entity.delete(recursive: true);
  }
}

class FilePickerCancelledException implements Exception {
  const FilePickerCancelledException();
}
