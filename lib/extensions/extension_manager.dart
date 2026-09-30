import 'dart:convert';
import 'dart:io';

import 'extension_manifest.dart';

class ExtensionManager {
  final List<ExtensionManifest> _extensions = [];

  List<ExtensionManifest> get extensions => List.unmodifiable(_extensions);

  Future<List<ExtensionManifest>> scan(Directory projectRoot) async {
    _extensions.clear();

    final directory = Directory(
      projectRoot.path + Platform.pathSeparator + '.pipedit' +
          Platform.pathSeparator + 'extensions',
    );

    if (!await directory.exists()) return extensions;

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! Directory) continue;

      final manifestFile = File(
        entity.path + Platform.pathSeparator + 'extension.json',
      );
      if (!await manifestFile.exists()) continue;

      try {
        final json = jsonDecode(await manifestFile.readAsString());
        if (json is Map<String, dynamic>) {
          final manifest = ExtensionManifest.fromJson(json);
          if (manifest.id.isNotEmpty && manifest.name.isNotEmpty) {
            _extensions.add(manifest);
          }
        }
      } catch (_) {
        // A broken extension must not break the editor.
      }
    }

    return extensions;
  }
}
