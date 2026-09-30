import 'package:flutter/material.dart';

import 'app/editor_shell.dart';

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
