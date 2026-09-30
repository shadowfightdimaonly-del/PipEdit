typedef EditorCommand = Future<void> Function();

class CommandRegistry {
  final Map<String, EditorCommand> _commands = {};

  void register(String id, EditorCommand command) {
    _commands[id] = command;
  }

  bool contains(String id) => _commands.containsKey(id);

  Future<void> execute(String id) async {
    final command = _commands[id];
    if (command == null) {
      throw StateError('Команда расширения не найдена: ' + id);
    }
    await command();
  }

  List<String> get ids => List.unmodifiable(_commands.keys);
}
