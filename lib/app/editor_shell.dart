import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/dart.dart';

import '../core/project_controller.dart';
import '../models/editor_file.dart';
import 'project_tree.dart';

class _ProjectSearchResult {
  const _ProjectSearchResult({required this.file, required this.line, required this.snippet});
  final File file;
  final int line;
  final String snippet;
}

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
  final Map<EditorFile, List<String>> _history = {};
  final Map<EditorFile, int> _historyIndex = {};
  bool _restoringHistory = false;
  FileSystemEntity? _selectedEntity;
  EditorFile? _selected;
  File? _selectedDiskFile;
  List<FileSystemEntity> _projectEntries = [];

  CodeController _controllerFor(EditorFile file) {
    _history.putIfAbsent(file, () => [file.content]);
    _historyIndex.putIfAbsent(file, () => 0);
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
      editorFile.name = name;
      editorFile.path = file.path;
      editorFile.isDirty = false;
      _history[editorFile] = [content];
      _historyIndex[editorFile] = 0;
      _selected = editorFile;
      _selectedEntity = file;
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
      _history.remove(file);
      _historyIndex.remove(file);
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

  void _recordHistory(EditorFile file, String value) {
    if (_restoringHistory) return;
    final history = _history.putIfAbsent(file, () => [file.content]);
    var index = _historyIndex[file] ?? 0;
    if (index < history.length - 1) history.removeRange(index + 1, history.length);
    if (history.isEmpty || history.last != value) {
      history.add(value);
      if (history.length > 100) history.removeAt(0);
      index = history.length - 1;
    }
    _historyIndex[file] = index;
  }

  void _restoreHistory(EditorFile file, String value) {
    _restoringHistory = true;
    file.content = value;
    _controllerFor(file).fullText = value;
    _restoringHistory = false;
    if (mounted) setState(() => file.isDirty = true);
  }

  void _undo() {
    final file = _selected;
    if (file == null) return;
    final history = _history[file];
    final index = _historyIndex[file] ?? 0;
    if (history == null || index <= 0) return;
    _historyIndex[file] = index - 1;
    _restoreHistory(file, history[index - 1]);
  }

  void _redo() {
    final file = _selected;
    if (file == null) return;
    final history = _history[file];
    final index = _historyIndex[file] ?? 0;
    if (history == null || index >= history.length - 1) return;
    _historyIndex[file] = index + 1;
    _restoreHistory(file, history[index + 1]);
  }

  Future<void> _renameEntity(FileSystemEntity? entity) async {
    if (entity == null) return;
    final oldName = entity.path.split(Platform.pathSeparator).last;
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Переименовать'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Переименовать')),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == oldName) return;
    try {
      final renamed = await _project.rename(entity, newName);
      final open = _files.where((item) => item.path == entity.path).toList();
      for (final file in open) {
        file.name = newName;
        file.path = renamed.path;
      }
      if (_selectedEntity?.path == entity.path) _selectedEntity = renamed;
      await _refreshProject();
      if (mounted) setState(() {});
    } catch (e) {
      _showError('Не удалось переименовать: $e');
    }
  }

  Future<void> _showQuickOpen() async {
    if (!_project.hasProject) { _showError('Сначала откройте проект'); return; }
    final files = <File>[];
    await for (final entity in _project.projectDirectory!.list(recursive: true, followLinks: false)) {
      if (entity is File) files.add(entity);
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    final query = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final q = query.text.toLowerCase();
          final visible = files.where((f) => f.path.toLowerCase().contains(q)).take(100).toList();
          return AlertDialog(
            title: const Text('Быстро открыть'),
            content: SizedBox(width: 600, height: 500, child: Column(children: [
              TextField(controller: query, autofocus: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Имя или путь файла'), onChanged: (_) => setDialogState(() {})),
              const SizedBox(height: 10),
              Expanded(child: ListView.builder(itemCount: visible.length, itemBuilder: (context, index) {
                final file = visible[index];
                return ListTile(dense: true, title: Text(file.path, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () async { Navigator.pop(dialogContext); await _openDiskFile(file); });
              })),
            ])),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Закрыть'))],
          );
        },
      ),
    );
    query.dispose();
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
              final value = file.content.replaceAll(find.text, replacement.text);
              _restoringHistory = true;
              _controllerFor(file).fullText = value;
              _restoringHistory = false;
              file.content = value;
              _recordHistory(file, value);
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
    List<_ProjectSearchResult> results = [];
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
                              itemBuilder: (context, index) {
                                final result = results[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.description_outlined),
                                  title: Text(
                                    '${result.file.path.split(Platform.pathSeparator).last}:${result.line}',
                                  ),
                                  subtitle: Text(
                                    result.snippet,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () async {
                                    Navigator.pop(dialogContext);
                                    await _openSearchResult(result);
                                  },
                                );
                              },
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

  Future<List<_ProjectSearchResult>> _searchProject(String query) async {
    final text = query.trim().toLowerCase();
    if (text.isEmpty || !_project.hasProject) return [];

    final matches = <_ProjectSearchResult>[];
    await for (final entity in _project.projectDirectory!
        .list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      try {
        final content = await entity.readAsString();
        final lines = content.split('\\n');
        for (var index = 0; index < lines.length; index++) {
          if (lines[index].toLowerCase().contains(text)) {
            matches.add(
              _ProjectSearchResult(
                file: entity,
                line: index + 1,
                snippet: lines[index].trim(),
              ),
            );
          }
        }
      } catch (_) {
        // Skip binary or unreadable files.
      }
    }

    matches.sort((a, b) {
      final pathCompare = a.file.path.compareTo(b.file.path);
      return pathCompare != 0 ? pathCompare : a.line.compareTo(b.line);
    });
    return matches;
  }

  Future<void> _openSearchResult(_ProjectSearchResult result) async {
    await _openDiskFile(result.file);
    final file = _selected;
    if (file == null) return;

    final lines = file.content.split('\\n');
    if (result.line < 1 || result.line > lines.length) return;

    var offset = 0;
    for (var i = 0; i < result.line - 1; i++) {
      offset += lines[i].length + 1;
    }

    _controllerFor(file).selection = TextSelection.collapsed(offset: offset);
    if (mounted) setState(() {});
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
              IconButton(tooltip: 'Быстро открыть', onPressed: _showQuickOpen, icon: const Icon(Icons.manage_search)),
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
                tooltip: 'Переименовать',
                onPressed: () => _renameEntity(_selectedEntity),
                icon: const Icon(Icons.drive_file_rename_outline),
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
            IconButton(tooltip: 'Отменить', onPressed: _undo, icon: const Icon(Icons.undo)),
            IconButton(tooltip: 'Повторить', onPressed: _redo, icon: const Icon(Icons.redo)),
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
                        onEntityTap: (entity) => setState(() => _selectedEntity = entity),
                        onEntityLongPress: _renameEntity,
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
                              _recordHistory(selected, value);
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
