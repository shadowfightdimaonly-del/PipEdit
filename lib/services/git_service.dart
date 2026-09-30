import 'dart:io';

class GitResult {
  const GitResult({required this.output, required this.exitCode});

  final String output;
  final int exitCode;
}

class GitService {
  Future<GitResult> _run(Directory project, List<String> args) async {
    try {
      final result = await Process.run(
        'git',
        args,
        workingDirectory: project.path,
        runInShell: false,
      );
      final output = result.stdout.toString() + result.stderr.toString();
      return GitResult(
        output: output.trim(),
        exitCode: result.exitCode is int ? result.exitCode as int : 1,
      );
    } catch (error) {
      return GitResult(output: 'Git недоступен: ' + error.toString(), exitCode: 1);
    }
  }

  Future<GitResult> status(Directory project) => _run(project, <String>['status', '--short']);

  Future<GitResult> log(Directory project) => _run(project, <String>['log', '--oneline', '-20']);

  Future<GitResult> diff(Directory project) => _run(project, <String>['diff']);

  Future<GitResult> addAll(Directory project) => _run(project, <String>['add', '-A']);

  Future<GitResult> commit(Directory project, String message) =>
      _run(project, <String>['commit', '-m', message]);
}
