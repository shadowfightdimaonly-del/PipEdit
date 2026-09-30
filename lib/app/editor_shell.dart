import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/dart.dart';

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
    EditorFile(
      name: 'main.dart',
      content: 'void main() {\n  print("Hello from PipEdit!");\n}\n',
    ),
    EditorFile(
      name: 'README.md',
      content: '# PipEdit\n\nДобро пожаловать в PipEdit.\n',
    ),
  ];

  final Map<EditorFile, CodeController> _controllers = {};
  final List<EditorFile> _openFiles = [];
  EditorFile? _selected;
  File? _selectedDiskFile;
  List<FileSystemEntity> _projectEntries = [];

  CodeController _controllerFor(EditorFile file) {
    return _controllers.putIfAbsent(
      file,
      () => CodeController(
        text: file.content,
        language: file.extension == 'dart' ? dart : null,
      ),
    );
  }

  Future<void> _refreshProject() async {
    if (!_project.hasProject) return;
    final entries = await _project.listProjectFiles();
    if (mounted) setState(() => _projectEntries = entries);
  }

  Future<void> _openProject() async {
    try {
      final directory = await _project.fileSystem.pickProjectDirectory();
      await _project.openProject(directory);
      await _refreshProject();
    } on FilePickerCancelledException {
      // User simply closed the picker.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть проект: $e')),
      );
    }
  }

  Future<void> _openDiskFile(File file) async {
    try {
      final content = await _project.read(file);
      final name = file.path.split(Platform.pathSeparator).last;
      EditorFile? editorFile;

      for (final item in _files) {
        if (item.name == name && item.path == file.path) {
          editorFile = item;
          break;
        }
      }

      editorFile ??= EditorFile(name: name, content: content, path: file.path);
      if (!_files.contains(editorFile)) _files.add(editorFile);

      editorFile.content = content;
      _selected = editorFile;
      _selectedDiskFile = file;

      final controller = _controllerFor(editorFile);
      controller.fullText = content;

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
      file.isDirty = false;
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

  Future<String?> _askName(String title, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.isEmpty ?? true ? null : result;
  }

  Future<void> _createFile() async {
    if (!_project.hasProject) return;
    final name = await _askName('Новый файл', 'например: main.dart');
    if (name == null) return;

    try {
      await _project.createFile(name);
      await _refreshProject();
    } catch (e) {
      _showError('Не удалось создать файл: $e');
    }
  }

  Future<void> _createFolder() async {
    if (!_project.hasProject) return;
    final name = await _askName('Новая папка', 'например: lib');
    if (name == null) return;

    try {
      await _project.createDirectory(name);
      await _refreshProject();
    } catch (e) {
      _showError('Не удалось создать папку: $e');
    }
  }

  Future<void> _deleteSelected() async {
    final file = _selectedDiskFile;
    if (file == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text(file.path.split(Platform.pathSeparator).last),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _project.delete(file);
      _selected = null;
      _selectedDiskFile = null;
      await _refreshProject();
    } catch (e) {
      _showError('Не удалось удалить: $e');
    }
  }

  Future<void> _closeFile(EditorFile file) async {
    if (file.isDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Есть несохранённые изменения'),
          content: Text('Сохранить изменения в '+file.name+'?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Не сохранять'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );

      if (discard == null) return;
      if (discard == true) {
        _selected = file;
        _selectedDiskFile = file.path == null ? null : File(file.path!);
        await _save();
        if (file.isDirty) return;
      }
    }

    setState(() {
      _openFiles.remove(file);
      _controllers.remove(file)?.dispose();
      if (_selected == file) {
        _selected = _openFiles.isEmpty ? null : _openFiles.last;
        final selected = _selected;
        _selectedDiskFile =
            selected?.path == null ? null : File(selected!.path!);
      }
    });
  }

  void _selectFile(EditorFile file) {
    setState(() {
      _selected = file;
      _selectedDiskFile =
          file.path == null ? null : File(file.path!);
      if (!_openFiles.contains(file)) _openFiles.add(file);
    });
  }

  Future<void> _showFindDialog() async {
    final input = TextEditingController();
    final file = _selected;
    if (file == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Поиск в файле'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Что найти',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final query = input.text;
              if (query.isEmpty) return;
              final index = file.content.indexOf(query);
              if (index == -1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Совпадений не найдено')),
                );
                return;
              }
              _controllerFor(file).selection = TextSelection(
                baseOffset: index,
                extentOffset: index + query.length,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Найти'),
          ),
        ],
      ),
    );
    input.dispose();
  }

  Future<void> _showReplaceDialog() async {
    final find = TextEditingController();
    final replacement = TextEditingController();
    final file = _selected;
    if (file == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Заменить в файле'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: find,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Найти'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replacement,
              decoration: const InputDecoration(labelText: 'Заменить на'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (find.text.isEmpty) return;
              final count = _countOccurrences(file.content, find.text);
              if (count == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Совпадений не найдено')),
                );
                return;
              }
              file.content = file.content.replaceAll(find.text, replacement.text);
              _controllerFor(file).fullText = file.content;
              setState(() => file.isDirty = true);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Заменено: $count')),
              );
            },
            child: const Text('Заменить всё'),
          ),
        ],
      ),
    );
    find.dispose();
    replacement.dispose();
  }

  int _countOccurrences(String text, String query) {
    if (query.isEmpty) return 0;
    var count = 0;
    var start = 0;
    while (true) {
      final index = text.indexOf(query, start);
      if (index == -1) return count;
      count++;
      start = index + query.length;
    }
  }

  Future<void> _showGoToLineDialog() async {
    final file = _selected;
    if (file == null) return;
    final input = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Перейти к строке'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Номер строки'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final line = int.tryParse(input.text);
              if (line == null || line < 1) return;
              final lines = file.content.split('\\n');
              if (line > lines.length) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('В файле только ${lines.length} строк')),
                );
                return;
              }
              var offset = 0;
              for (var i = 0; i < line - 1; i++) {
                offset += lines[i].length + 1;
              }
              _controllerFor(file).selection =
                  TextSelection.collapsed(offset: offset);
              Navigator.pop(dialogContext);
            },
            child: const Text('Перейти'),
          ),
        ],
      ),
    );
    input.dispose();
  }

  Future<void> _showProjectSearchDialog() async {
    if (!_project.hasProject) {
      _showError('Сначала откройте проект');
      return;
    }

    final input = TextEditingController();
    List<String> results = [];
    bool searching = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Поиск по проекту'),
          content: SizedBox(
            width: 560,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: input,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Текст для поиска',
                    prefixIcon: Icon(Icons.manage_search),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: searching
                      ? const Center(child: CircularProgressIndicator())
                      : results.isEmpty
                          ? const Center(child: Text('Результатов пока нет'))
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, index) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.description_outlined),
                                title: Text(results[index]),
                              ),
                            ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Закрыть'),
            ),
            FilledButton(
              onPressed: searching
                  ? null
                  : () async {
                      setDialogState(() => searching = true);
                      results = await _searchProject(input.text);
                      setDialogState(() => searching = false);
                    },
              child: const Text('Искать'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
  }

  Future<List<String>> _searchProject(String query) async {
    final text = query.trim().toLowerCase();
    if (text.isEmpty || !_project.hasProject) return [];

    final matches = <String>[];
    await for (final entity in _project.projectDirectory!
        .list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      try {
        final content = await entity.readAsString();
        if (content.toLowerCase().contains(text)) {
          matches.add(entity.path);
        }
      } catch (_) {
        // Skip binary or unreadable files.
      }
    }
    matches.sort();
    return matches;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    final codeController =
        selected == null ? null : _controllerFor(selected);

    return CodeTheme(
      data: CodeThemeData(styles: monokaiSublimeTheme),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PipEdit'),
          actions: [
            if (_project.hasProject) ...[
              IconButton(
                tooltip: 'Новый файл',
                onPressed: _createFile,
                icon: const Icon(Icons.note_add_outlined),
              ),
              IconButton(
                tooltip: 'Новая папка',
                onPressed: _createFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
              IconButton(
                tooltip: 'Удалить выбранное',
                onPressed: _deleteSelected,
                icon: const Icon(Icons.delete_outline),
              ),
              IconButton(
                tooltip: 'Обновить',
                onPressed: _refreshProject,
                icon: const Icon(Icons.refresh),
              ),
            ],
            IconButton(
              tooltip: 'Поиск в файле',
              onPressed: _showFindDialog,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Заменить',
              onPressed: _showReplaceDialog,
              icon: const Icon(Icons.find_replace),
            ),
            IconButton(
              tooltip: 'Перейти к строке',
              onPressed: _showGoToLineDialog,
              icon: const Icon(Icons.format_list_numbered),
            ),
            IconButton(
              tooltip: 'Открыть проект',
              onPressed: _openProject,
              icon: const Icon(Icons.folder_open),
            ),
            IconButton(
              tooltip: 'Сохранить',
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: Row(
          children: [
            SizedBox(
              width: 250,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: _project.hasProject
                    ? ProjectTree(
                        root: _project.projectDirectory!,
                        onFileTap: _openDiskFile,
                      )
                    : ListView(
                        children: [
                          const ListTile(
                            leading: Icon(Icons.folder_outlined),
                            title: Text('Проект'),
                          ),
                          for (final file in _files)
                            ListTile(
                              selected: file == selected,
                              leading: Icon(
                                file.extension == 'dart'
                                    ? Icons.code
                                    : Icons.description_outlined,
                              ),
                              title: Text(file.name),
                              onTap: () => _selectFile(file),
                            ),
                        ],
                      ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: selected == null || codeController == null
                  ? const Center(
                      child: Text(
                        'Откройте файл, чтобы начать редактирование',
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          height: 44,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            selected.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                      if (_openFiles.isNotEmpty)
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final file in _openFiles)
                                InkWell(
                                  onTap: () => _selectFile(file),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          width: 2,
                                          color: file == selected
                                              ? Theme.of(context).colorScheme.primary
                                              : Colors.transparent,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(file.name + (file.isDirty ? ' •' : '')),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => _closeFile(file),
                                          child: const Icon(Icons.close, size: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                        Expanded(
                          child: CodeField(
                            controller: codeController,
                            expands: true,
                            wrap: false,
                            padding: const EdgeInsets.all(12),
                            textStyle: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 15,
                            ),
                            gutterStyle: const GutterStyle(
                              showErrors: true,
                              showFoldingHandles: true,
                              showLineNumbers: true,
                              width: 64,
                            ),
                            onChanged: (value) {
                              selected.content = value;
                              if (!selected.isDirty) setState(() => selected.isDirty = true);
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
