import 'dart:io';

import 'package:flutter/material.dart';

class ProjectTree extends StatelessWidget {
  const ProjectTree({
    required this.entries,
    required this.onFileTap,
    super.key,
  });

  final List<FileSystemEntity> entries;
  final ValueChanged<File> onFileTap;

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]
      ..sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir != bDir) return aDir ? -1 : 1;
        return a.path.compareTo(b.path);
      });

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final entry = sorted[index];
        final name = entry.path.split(Platform.pathSeparator).last;

        if (entry is Directory) {
          return ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(name),
          );
        }

        return ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text(name),
          onTap: () => onFileTap(entry),
        );
      },
    );
  }
}
