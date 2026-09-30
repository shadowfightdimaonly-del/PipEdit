import 'command_registry.dart';

class EditorExtensionApi {
  EditorExtensionApi({required this.commands});

  final CommandRegistry commands;

  void registerCommand(String id, EditorCommand command) {
    commands.register(id, command);
  }

  bool hasCommand(String id) => commands.contains(id);

  Future<void> executeCommand(String id) => commands.execute(id);
}
