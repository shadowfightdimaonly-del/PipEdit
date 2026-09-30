import 'dart:io';

class TerminalResult {
  const TerminalResult({required this.output, required this.exitCode});

  final String output;
  final int exitCode;
}

class TerminalService {
  Future<TerminalResult> run(Directory project, String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty) {
      return const TerminalResult(output: 'Команда пустая.', exitCode: 1);
    }

    try {
      final result = await Process.run(
        'sh',
        <String>['-c', trimmed],
        workingDirectory: project.path,
        runInShell: false,
      );
      final output = result.stdout.toString() + result.stderr.toString();
      return TerminalResult(
        output: output.trim().isEmpty ? 'Команда выполнена.' : output,
        exitCode: result.exitCode is int ? result.exitCode as int : 1,
      );
    } catch (error) {
      return TerminalResult(output: 'Не удалось выполнить команду: ' + error.toString(), exitCode: 1);
    }
  }
}
