import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/file_system_service.dart';
import '../services/storage_access_service.dart';
import 'code_editor_screen.dart';

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen>
    with WidgetsBindingObserver {
  final StorageAccessService _access = StorageAccessService();
  Directory? _root;
  Directory? _current;
  List<FileSystemEntity> _entries = [];
  bool _loading = true;
  bool _hasFullAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final fullAccess = await _access.hasAllFilesAccess();
      Directory? root = _root;
      if (fullAccess) {
        final path = await _access.externalStorageRoot();
        if (path != null) root = Directory(path);
      }
      if (!mounted) return;
      setState(() {
        _hasFullAccess = fullAccess;
        _root = root;
        _current = root ?? _current;
      });
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Не удалось открыть файловую систему: $e');
    }
  }

  Future<void> _refresh() async {
    final directory = _current;
    if (directory == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final entries = await directory.list(followLinks: false).toList();
      entries.sort(_sortEntries);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Не удалось прочитать папку: $e');
    }
  }

  int _sortEntries(FileSystemEntity a, FileSystemEntity b) {
    final ad = a is Directory;
    final bd = b is Directory;
    if (ad != bd) return ad ? -1 : 1;
    return _name(a).toLowerCase().compareTo(_name(b).toLowerCase());
  }

  String _name(FileSystemEntity entity) {
    final normalized = entity.path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? entity.path : parts.last;
  }

  String _title() {
    final current = _current;
    if (current == null) return 'PipEdit';
    if (_root != null && current.path == _root!.path) {
      return 'Внутренняя память';
    }
    return _name(current);
  }

  Future<void> _openEntry(FileSystemEntity entity) async {
    if (entity is Directory) {
      setState(() => _current = entity);
      await _refresh();
      return;
    }
    if (entity is File) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CodeEditorScreen(file: entity)),
      );
      await _refresh();
    }
  }

  Future<void> _pickFolderWithoutFullAccess() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Выберите папку',
      );
      if (path == null) return;
      final directory = Directory(path);
      setState(() {
        _root = directory;
        _current = directory;
        _hasFullAccess = false;
      });
      await _refresh();
    } catch (e) {
      _showError('Не удалось выбрать папку: $e');
    }
  }

  Future<void> _requestFullAccess() async {
    await _access.requestAllFilesAccess();
  }

  Future<void> _createFile() async {
    final directory = _current;
    if (directory == null) return;
    final name = await _askName('Новый файл');
    if (name == null) return;
    try {
      await FileSystemService().createFile(directory, name);
      await _refresh();
    } catch (e) {
      _showError('Не удалось создать файл: $e');
    }
  }

  Future<void> _createFolder() async {
    final directory = _current;
    if (directory == null) return;
    final name = await _askName('Новая папка');
    if (name == null) return;
    try {
      await FileSystemService().createDirectory(directory, name);
      await _refresh();
    } catch (e) {
      _showError('Не удалось создать папку: $e');
    }
  }

  Future<String?> _askName(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Имя'),
          onSubmitted: (_) =>
              Navigator.pop(dialogContext, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result == null || result.isEmpty ? null : result;
  }

  Future<void> _createProject() async {
    final parentPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите место для проекта',
    );
    if (parentPath == null) return;
    final name = await _askName('Новый проект');
    if (name == null) return;
    try {
      final project = Directory(
        parentPath + Platform.pathSeparator + name,
      );
      await project.create();
      if (!mounted) return;
      setState(() {
        _root ??= project.parent;
        _current = project;
      });
      await _refresh();
      _showMessage('Проект создан');
    } catch (e) {
      _showError('Не удалось создать проект: $e');
    }
  }

  Future<void> _rename(FileSystemEntity entity) async {
    final controller = TextEditingController(text: _name(entity));
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Переименовать'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Имя'),
          onSubmitted: (_) =>
              Navigator.pop(dialogContext, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Переименовать'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == _name(entity)) {
      return;
    }
    try {
      await FileSystemService().rename(entity, newName);
      await _refresh();
    } catch (e) {
      _showError('Не удалось переименовать: $e');
    }
  }

  Future<void> _delete(FileSystemEntity entity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text(_name(entity)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FileSystemService().delete(entity);
      await _refresh();
    } catch (e) {
      _showError('Не удалось удалить: $e');
    }
  }

  Future<void> _copyOrMove(FileSystemEntity entity, {bool move = false}) async {
    final destinationPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: move ? 'Выберите папку назначения' : 'Копировать в',
    );
    if (destinationPath == null) return;
    try {
      await FileSystemService().copyOrMove(
        entity,
        Directory(destinationPath),
        move: move,
      );
      await _refresh();
      _showMessage(move ? 'Перемещено' : 'Скопировано');
    } catch (e) {
      _showError('Операция не выполнена: $e');
    }
  }

  void _showActions(FileSystemEntity entity) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                entity is Directory
                    ? Icons.folder_open_outlined
                    : Icons.edit_outlined,
              ),
              title: Text(entity is Directory ? 'Открыть' : 'Редактировать'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openEntry(entity);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Переименовать'),
              onTap: () {
                Navigator.pop(sheetContext);
                _rename(entity);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Копировать'),
              onTap: () {
                Navigator.pop(sheetContext);
                _copyOrMove(entity);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: const Text('Переместить'),
              onTap: () {
                Navigator.pop(sheetContext);
                _copyOrMove(entity, move: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Информация'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showInfo(entity);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Удалить'),
              onTap: () {
                Navigator.pop(sheetContext);
                _delete(entity);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInfo(FileSystemEntity entity) async {
    try {
      final stat = await entity.stat();
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(_name(entity)),
          content: SelectableText(
            'Путь: ${entity.path}\n'
            'Размер: ${stat.size} байт\n'
            'Изменён: ${stat.modified}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Не удалось получить информацию: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final canGoBack =
        current != null && _root != null && current.path != _root!.path;

    return Scaffold(
      appBar: AppBar(
        leading: canGoBack
            ? IconButton(
                tooltip: 'Назад',
                onPressed: () async {
                  final parent = current.parent;
                  setState(() => _current = parent);
                  await _refresh();
                },
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(_title()),
        actions: [
          if (current != null) ...[
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
          ],
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'choose':
                  _pickFolderWithoutFullAccess();
                case 'access':
                  _requestFullAccess();
                case 'project':
                  _createProject();
                case 'refresh':
                  _refresh();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'choose',
                child: Text('Выбрать папку'),
              ),
              if (!_hasFullAccess)
                const PopupMenuItem(
                  value: 'access',
                  child: Text('Разрешить доступ ко всем файлам'),
                ),
              const PopupMenuItem(
                value: 'project',
                child: Text('Создать проект'),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Text('Обновить'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : current == null
              ? _buildNoAccess()
              : _entries.isEmpty
                  ? const Center(child: Text('Папка пуста'))
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _entries.length,
                        itemBuilder: (_, index) {
                          final entity = _entries[index];
                          final directory = entity is Directory;
                          return ListTile(
                            leading: Icon(
                              directory
                                  ? Icons.folder_outlined
                                  : Icons.insert_drive_file_outlined,
                            ),
                            title: Text(
                              _name(entity),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _openEntry(entity),
                            onLongPress: () => _showActions(entity),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildNoAccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_outlined, size: 72),
            const SizedBox(height: 16),
            const Text(
              'Выберите папку или разрешите PipEdit доступ ко всем файлам.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _requestFullAccess,
              icon: const Icon(Icons.folder_shared_outlined),
              label: const Text('Доступ ко всем файлам'),
            ),
            TextButton(
              onPressed: _pickFolderWithoutFullAccess,
              child: const Text('Выбрать папку'),
            ),
            TextButton(
              onPressed: _createProject,
              child: const Text('Создать проект'),
            ),
          ],
        ),
      ),
    );
  }
}