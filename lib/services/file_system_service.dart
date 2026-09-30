import 'dart:io';

class FileSystemService {
  Future<Directory> pickProjectDirectory() async {
    throw UnsupportedError(
      'Выбор папки будет подключён через системный file picker.',
    );
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

  Future<void> delete(FileSystemEntity entity) => entity.delete(recursive: true);
}
