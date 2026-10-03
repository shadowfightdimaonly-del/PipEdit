import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/cs.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/html.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/kotlin.dart';
import 'package:highlight/languages/lua.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CodeEditorScreen extends StatefulWidget {
  const CodeEditorScreen({required this.file, super.key});

  final File file;

  @override
  State<CodeEditorScreen> createState() => _CodeEditorScreenState();
}

class _CodeEditorScreenState extends State<CodeEditorScreen> {
  static const _fontSizeKey = 'editor_font_size';
  static const _defaultFontSize = 15.0;
  static const _minFontSize = 10.0;
  static const _maxFontSize = 24.0;

  late final CodeController _controller;
  late String _original;
  bool _saving = false;
  double _fontSize = _defaultFontSize;

  bool get _dirty => _controller.fullText != _original;

  @override
  void initState() {
    super.initState();
    _controller = CodeController(
      text: '',
      language: _languageFor(widget.file),
      analyzer: const DefaultLocalAnalyzer(),
    );
    _original = '';
    _loadFontSize();
    _load();
  }

  Future<void> _loadFontSize() async {
    final preferences = await SharedPreferences.getInstance();
    final savedSize = preferences.getDouble(_fontSizeKey);
    if (!mounted || savedSize == null) return;

    setState(() {
      _fontSize = savedSize.clamp(_minFontSize, _maxFontSize).toDouble();
    });
  }

  Future<void> _showFontSizeDialog() async {
    var selectedSize = _fontSize;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Размер текста'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\${selectedSize.toStringAsFixed(0)} px',
                style: const TextStyle(fontSize: 18),
              ),
              Slider(
                value: selectedSize,
                min: _minFontSize,
                max: _maxFontSize,
                divisions: 14,
                label: '\${selectedSize.toStringAsFixed(0)} px',
                onChanged: (value) {
                  setDialogState(() => selectedSize = value);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      setDialogState(() => selectedSize = _defaultFontSize);
                    },
                    child: const Text('Сбросить'),
                  ),
                  const Text('10–24 px'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                final preferences = await SharedPreferences.getInstance();
                await preferences.setDouble(_fontSizeKey, selectedSize);
                if (!mounted) return;
                setState(() => _fontSize = selectedSize);
                Navigator.pop(dialogContext);
              },
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
  }

  dynamic _languageFor(File file) {
    final extension = file.path.split('.').last.toLowerCase();

    switch (extension) {
      case 'dart':
        return dart;
      case 'json':
      case 'json5':
        return json;
      case 'js':
      case 'mjs':
      case 'cjs':
        return javascript;
      case 'ts':
      case 'tsx':
        return typescript;
      case 'yaml':
      case 'yml':
        return yaml;
      case 'xml':
      case 'svg':
        return xml;
      case 'html':
      case 'htm':
        return html;
      case 'css':
        return css;
      case 'py':
        return python;
      case 'java':
        return java;
      case 'kt':
      case 'kts':
        return kotlin;
      case 'c':
      case 'h':
      case 'cc':
      case 'cpp':
      case 'cxx':
      case 'hpp':
        return cpp;
      case 'cs':
        return cs;
      case 'go':
        return go;
      case 'rs':
        return rust;
      case 'sh':
      case 'bash':
        return bash;
      case 'lua':
        return lua;
      case 'sql':
        return sql;
      case 'md':
      case 'markdown':
        return markdown;
      default:
        return null;
    }
  }

  Future<void> _load() async {
    try {
      final content = await widget.file.readAsString();
      _original = content;
      _controller.fullText = content;
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть файл: $e')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.file.writeAsString(_controller.fullText);
      _original = _controller.fullText;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сохранено')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmExit() async {
    if (!_dirty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: Text(
          'Сохранить изменения в ${widget.file.path.split(Platform.pathSeparator).last}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('Не сохранять'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _save();
      if (!_dirty && mounted) Navigator.pop(context);
    } else if (result == 'discard' && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _find() async {
    final query = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Поиск'),
        content: TextField(
          controller: query,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Найти'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = query.text;
              if (value.isEmpty) return;
              final index = _controller.fullText.indexOf(value);
              if (index == -1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Совпадений не найдено')),
                );
                return;
              }
              _controller.selection = TextSelection(
                baseOffset: index,
                extentOffset: index + value.length,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Найти'),
          ),
        ],
      ),
    );
    query.dispose();
  }

  Future<void> _replace() async {
    final find = TextEditingController();
    final replacement = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Заменить'),
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
              _controller.fullText =
                  _controller.fullText.replaceAll(find.text, replacement.text);
              Navigator.pop(dialogContext);
              setState(() {});
            },
            child: const Text('Заменить всё'),
          ),
        ],
      ),
    );
    find.dispose();
    replacement.dispose();
  }

  Future<void> _goToLine() async {
    final input = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Перейти к строке'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Номер строки'),
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
              final lines = _controller.fullText.split('\n');
              if (line > lines.length) return;
              var offset = 0;
              for (var i = 0; i < line - 1; i++) {
                offset += lines[i].length + 1;
              }
              _controller.selection = TextSelection.collapsed(offset: offset);
              Navigator.pop(dialogContext);
            },
            child: const Text('Перейти'),
          ),
        ],
      ),
    );
    input.dispose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.file.path.split(Platform.pathSeparator).last;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: CodeTheme(
        data: CodeThemeData(styles: monokaiSublimeTheme),
        child: Scaffold(
          backgroundColor: const Color(0xFF11101A),
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Назад',
              onPressed: _confirmExit,
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(name, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'Размер текста',
                onPressed: _showFontSizeDialog,
                icon: const Icon(Icons.format_size),
              ),
              IconButton(
                tooltip: 'Поиск',
                onPressed: _find,
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'Заменить',
                onPressed: _replace,
                icon: const Icon(Icons.find_replace),
              ),
              IconButton(
                tooltip: 'Перейти к строке',
                onPressed: _goToLine,
                icon: const Icon(Icons.format_list_numbered),
              ),
              IconButton(
                tooltip: 'Сохранить',
                onPressed: _save,
                icon: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
              ),
            ],
          ),
          body: CodeField(
            controller: _controller,
            expands: true,
            wrap: false,
            background: const Color(0xFF11101A),
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            padding: const EdgeInsets.all(12),
            textStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: _fontSize,
            ),
            gutterStyle: GutterStyle(
              showErrors: true,
              showFoldingHandles: true,
              showLineNumbers: true,
              width: 56,
              textStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: _fontSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
