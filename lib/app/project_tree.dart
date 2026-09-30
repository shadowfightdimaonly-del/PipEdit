import 'dart:io';

import 'package:flutter/material.dart';

class ProjectTree extends StatefulWidget {
  const ProjectTree({
    required this.root,
    required this.onFileTap,
    this.onEntityTap,
    this.onEntityLongPress,
    super.key,
  });

  final Directory root;
  final ValueChanged<File> onFileTap;
  final ValueChanged<FileSystemEntity>? onEntityTap;
  final ValueChanged<FileSystemEntity>? onEntityLongPress;

  @override
  State<ProjectTree> createState() => _ProjectTreeState();
}

class _ProjectTreeState extends State<ProjectTree> {
  final Set<String> _expanded = {};
  final Map<String, List<FileSystemEntity>> _children = {};
  final Set<String> _loading = {};

  Future<void> _toggleDirectory(Directory directory) async {
    final path = directory.path;

    if (_expanded.contains(path)) {
      setState(() => _expanded.remove(path));
      return;
    }

    if (!_children.containsKey(path)) {
      setState(() => _loading.add(path));
      try {
        final entries = await directory.list(followLinks: false).toList();
        entries.sort(_sortEntries);
        _children[path] = entries;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось открыть ' + _name(directory))),
          );
        }
      } finally {
        if (mounted) setState(() => _loading.remove(path));
      }
    }

    if (mounted && _children.containsKey(path)) {
      setState(() => _expanded.add(path));
    }
  }

  int _sortEntries(FileSystemEntity a, FileSystemEntity b) {
    final aDir = a is Directory;
    final bDir = b is Directory;
    if (aDir != bDir) return aDir ? -1 : 1;
    return _name(a).toLowerCase().compareTo(_name(b).toLowerCase());
  }

  String _name(FileSystemEntity entity) {
    final normalized = entity.path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? entity.path : parts.last;
  }

  List<Widget> _buildEntries(List<FileSystemEntity> entries, int depth) {
    final result = <Widget>[];

    for (final entry in entries) {
      final name = _name(entry);

      if (entry is Directory) {
        final expanded = _expanded.contains(entry.path);
        final loading = _loading.contains(entry.path);

        result.add(
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(
              left: 12.0 + depth * 18.0,
              right: 8,
            ),
            leading: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(expanded ? Icons.folder_open : Icons.folder_outlined),
            title: Text(name, overflow: TextOverflow.ellipsis),
            onTap: () {
              widget.onEntityTap?.call(entry);
              _toggleDirectory(entry);
            },
            onLongPress: () => widget.onEntityLongPress?.call(entry),
          ),
        );

        if (expanded) {
          final children = _children[entry.path] ?? const [];
          result.addAll(_buildEntries(children, depth + 1));
        }
      } else {
        result.add(
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(
              left: 12.0 + depth * 18.0,
              right: 8,
            ),
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(name, overflow: TextOverflow.ellipsis),
            onTap: () {
              widget.onEntityTap?.call(entry);
              widget.onFileTap(entry as File);
            },
            onLongPress: () => widget.onEntityLongPress?.call(entry),
          ),
        );
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FileSystemEntity>>(
      future: widget.root.list(followLinks: false).toList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Ошибка чтения проекта: ' + snapshot.error.toString()),
          );
        }

        final entries = [...?snapshot.data]..sort(_sortEntries);

        return ListView(children: _buildEntries(entries, 0));
      },
    );
  }
}
