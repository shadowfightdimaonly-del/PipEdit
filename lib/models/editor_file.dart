class EditorFile {
  const EditorFile({
    required this.name,
    required this.content,
    this.isDirectory = false,
  });

  final String name;
  String content;
  final bool isDirectory;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }
}
