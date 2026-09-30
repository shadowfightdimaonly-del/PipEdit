import 'dart:io';

class WorkspaceState {
  WorkspaceState({this.project});

  Directory? project;
  String? currentFilePath;
  bool terminalOpen = false;
  bool gitOpen = false;
  String? activeTheme = 'dark';
}
