import 'package:flutter/material.dart';

void main() {
  runApp(const PipEditApp());
}

class PipEditApp extends StatelessWidget {
  const PipEditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PipEdit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const EditorShell(),
    );
  }
}

class EditorShell extends StatefulWidget {
  const EditorShell({super.key});

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  final List<String> _files = ['main.dart', 'README.md'];
  final Map<String, String> _contents = {
    'main.dart': 'void main() {\n  print("Hello from PipEdit!");\n}\n',
    'README.md': '# PipEdit\n\nДобро пожаловать в PipEdit.\n',
  };

  String _selectedFile = 'main.dart';

  @override
  Widget build(BuildContext context) {
    final content = _contents[_selectedFile] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('PipEdit'),
        actions: [
          IconButton(
            tooltip: 'Сохранить',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Изменения сохранены')),
              );
            },
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 230,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListView(
                children: [
                  const ListTile(
                    leading: Icon(Icons.folder_outlined),
                    title: Text('Проект'),
                  ),
                  for (final file in _files)
                    ListTile(
                      selected: file == _selectedFile,
                      leading: Icon(
                        file.endsWith('.dart')
                            ? Icons.code
                            : Icons.description_outlined,
                      ),
                      title: Text(file),
                      onTap: () => setState(() => _selectedFile = file),
                    ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 44,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _selectedFile,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Начните писать код...',
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                      ),
                      controller: TextEditingController.fromValue(
                        TextEditingValue(
                          text: content,
                          selection: TextSelection.collapsed(
                            offset: content.length,
                          ),
                        ),
                      ),
                      onChanged: (value) => _contents[_selectedFile] = value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
