class ExtensionManifest {
  const ExtensionManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    this.entrypoint,
    this.commands = const [],
  });

  final String id;
  final String name;
  final String version;
  final String description;
  final String? entrypoint;
  final List<String> commands;

  factory ExtensionManifest.fromJson(Map<String, dynamic> json) {
    final rawCommands = json['commands'];
    return ExtensionManifest(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      version: json['version']?.toString() ?? '0.0.0',
      description: json['description']?.toString() ?? '',
      entrypoint: json['entrypoint']?.toString(),
      commands: rawCommands is List
          ? rawCommands.map((item) => item.toString()).toList()
          : const [],
    );
  }
}
