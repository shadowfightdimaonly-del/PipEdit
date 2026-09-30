import 'package:flutter/material.dart';

import '../core/editor_controller.dart';
import '../models/editor_file.dart';

class EditorShell extends StatefulWidget {
  const EditorShell({super.key});

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  final EditorController _controller = EditorController();
  final Map<String, TextEditingController> _textControllers = {};

  TextEditingController _controllerFor(EditorFile file) {
    return _textControllers.putIfAbsent(
      file.name,
      () => TextEditingController(text: file.content),
    );
  }

  void _selectFile(EditorFile file) {
    setState(() => _controller.select(file));
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = _controller.selected;
    final textController = _controllerFor(file);

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
                  for (final currentFile in _controller.files)
                    ListTile(
                      selected: currentFile == file,
                      leading: Icon(
                        currentFile.extension == 'dart'
                            ? Icons.code
                            : Icons.description_outlined,
                      ),
                      title: Text(currentFile.name),
                      onTap: () => _selectFile(currentFile),
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
                    file.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: textController,
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
                      onChanged: (value) {
                        _controller.updateContent(file, value);
                      },
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
