# Extensions

Система расширений PipEdit теперь имеет минимальное ядро.

## Manifest

Расширение хранится в:

`.pipedit/extensions/<extension>/extension.json`

Пример:

```json
{
  "id": "pipis.dart-tools",
  "name": "Dart Tools",
  "version": "0.1.0",
  "description": "Инструменты Dart для PipEdit",
  "commands": ["dart.format"]
}
```

## Безопасность

На этом этапе PipEdit только обнаруживает и читает манифесты.
Автоматического выполнения произвольного кода расширений нет.
Сначала нужен стабильный API редактора, потом уже исполнение плагинов. Человечество переживёт ещё один релиз без удалённого выполнения кода.

Ядро находится в `lib/extensions/`:
- `ExtensionManifest`
- `ExtensionManager`
- `CommandRegistry`
