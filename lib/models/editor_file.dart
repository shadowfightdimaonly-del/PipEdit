class EditorFile {
  EditorFile({
    required this.name,
    required this.content,
    this.isDirectory = false,
    this.path,
  });

  final String name;
  String content;
  final bool isDirectory;
  final String? path;

  bool isDirty = false;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }
}
