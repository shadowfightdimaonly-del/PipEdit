import '../models/editor_file.dart';

class EditorController {
  EditorController()
      : files = [
          EditorFile(
            name: 'main.dart',
            content: 'void main() {\n  print("Hello from PipEdit!");\n}\n',
          ),
          EditorFile(
            name: 'README.md',
            content: '# PipEdit\n\nДобро пожаловать в PipEdit.\n',
          ),
        ];

  final List<EditorFile> files;
  EditorFile? _selected;

  EditorFile get selected => _selected ?? files.first;

  void select(EditorFile file) {
    _selected = file;
  }

  void updateContent(EditorFile file, String value) {
    file.content = value;
  }
}
