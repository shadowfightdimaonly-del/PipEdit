import 'dart:io';

import 'package:flutter/material.dart';

import '../core/project_controller.dart';
import '../models/editor_file.dart';
import 'project_tree.dart';

class EditorShell extends StatefulWidget {
  const EditorShell({super.key});

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  final ProjectController _project = ProjectController();
  final List<EditorFile> _files = [
    EditorFile(name: 'main.dart', content: 'void main() {\n  print("Hello from PipEdit!");\n}\n'),
    EditorFile(name: 'README.md', content: '# PipEdit\n\nДобро пожаловать в PipEdit.\n'),
  ];

  final Map<String, TextEditingController> _controllers = {};
  EditorFile? _selected;
  File? _selectedDiskFile;
  List<FileSystemEntity> _projectEntries = [];

  TextEditingController _controllerFor(EditorFile file) {
    return _controllers.putIfAbsent(file.name, () => TextEditingController(text: file.content));
  }

  Future<void> _openProject() async {
    try {
      final directory = await _project.fileSystem.pickProjectDirectory();
      await _project.openProject(directory);
      final entries = await _project.listProjectFiles();
      if (!mounted) return;
      setState(() => _projectEntries = entries);
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Выбор папки пока не подключён')),
      );
    }
  }

  Future<void> _openDiskFile(File file) async {
    try {
      final content = await _project.read(file);
      final name = file.path.split(Platform.pathSeparator).last;
      EditorFile? editorFile;
      for (final item in _files) {
        if (item.name == name) {
          editorFile = item;
          break;
        }
      }
      if (editorFile == null) {
        editorFile = EditorFile(name: name, content: content);
        _files.add(editorFile);
      }
      editorFile.content = content;
      _selected = editorFile;
      _selectedDiskFile = file;
      _controllerFor(editorFile).text = content;
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть файл: $e')),
      );
    }
  }

  Future<void> _save() async {
    final file = _selected;
    final diskFile = _selectedDiskFile;
    if (file == null || diskFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала откройте файл проекта')),
      );
      return;
    }
    try {
      await _project.save(diskFile, file.content);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(file.name + ' сохранён')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final textController = selected == null ? null : _controllerFor(selected);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PipEdit'),
        actions: [
          IconButton(tooltip: 'Открыть проект', onPressed: _openProject, icon: const Icon(Icons.folder_open)),
          IconButton(tooltip: 'Сохранить', onPressed: _save, icon: const Icon(Icons.save_outlined)),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 250,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: _project.hasProject
                  ? ProjectTree(entries: _projectEntries, onFileTap: _openDiskFile)
                  : ListView(
                      children: [
                        const ListTile(leading: Icon(Icons.folder_outlined), title: Text('Проект')),
                        for (final file in _files)
                          ListTile(
                            selected: file == selected,
                            leading: Icon(file.extension == 'dart' ? Icons.code : Icons.description_outlined),
                            title: Text(file.name),
                            onTap: () => setState(() {
                              _selected = file;
                              _selectedDiskFile = null;
                            }),
                          ),
                      ],
                    ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: selected == null || textController == null
                ? const Center(child: Text('Откройте файл, чтобы начать редактирование'))
                : Column(
                    children: [
                      Container(
                        height: 44,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(selected.name, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Начните писать код...'),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
                            onChanged: (value) => selected.content = value,
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
