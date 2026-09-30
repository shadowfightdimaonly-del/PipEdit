import 'dart:io';

import 'package:flutter/material.dart';

import '../services/terminal_service.dart';
import '../services/git_service.dart';

class ToolPanel extends StatefulWidget {
  const ToolPanel({
    required this.project,
    super.key,
  });

  final Directory project;

  @override
  State<ToolPanel> createState() => _ToolPanelState();
}

class _ToolPanelState extends State<ToolPanel> {
  final TerminalService _terminal = TerminalService();
  final GitService _git = GitService();
  final TextEditingController _command = TextEditingController();
  final TextEditingController _commit = TextEditingController();
  String _output = '';

  Future<void> _runCommand() async {
    final result = await _terminal.run(widget.project, _command.text);
    if (!mounted) return;
    setState(() => _output = result.output);
  }

  Future<void> _gitStatus() async {
    final result = await _git.status(widget.project);
    if (!mounted) return;
    setState(() => _output = result.output.isEmpty ? 'Рабочее дерево чисто.' : result.output);
  }

  Future<void> _gitLog() async {
    final result = await _git.log(widget.project);
    if (!mounted) return;
    setState(() => _output = result.output);
  }

  Future<void> _gitDiff() async {
    final result = await _git.diff(widget.project);
    if (!mounted) return;
    setState(() => _output = result.output);
  }

  Future<void> _gitCommit() async {
    if (_commit.text.trim().isEmpty) return;
    await _git.addAll(widget.project);
    final result = await _git.commit(widget.project, _commit.text.trim());
    if (!mounted) return;
    setState(() => _output = result.output);
  }

  @override
  void dispose() {
    _command.dispose();
    _commit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Terminal / Git'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Git status',
                  onPressed: _gitStatus,
                  icon: const Icon(Icons.account_tree_outlined),
                ),
                IconButton(
                  tooltip: 'Git log',
                  onPressed: _gitLog,
                  icon: const Icon(Icons.history),
                ),
                IconButton(
                  tooltip: 'Git diff',
                  onPressed: _gitDiff,
                  icon: const Icon(Icons.compare_arrows),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _command,
                      decoration: const InputDecoration(
                        prefixText: r'$ ',
                        hintText: 'команда',
                      ),
                      onSubmitted: (_) => _runCommand(),
                    ),
                  ),
                  IconButton(
                    onPressed: _runCommand,
                    icon: const Icon(Icons.play_arrow),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commit,
                      decoration: const InputDecoration(
                        hintText: 'сообщение commit',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Commit',
                    onPressed: _gitCommit,
                    icon: const Icon(Icons.commit),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _output.isEmpty ? 'Готово.' : _output,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
