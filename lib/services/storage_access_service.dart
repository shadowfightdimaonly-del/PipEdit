import 'package:flutter/services.dart';

class StorageAccessService {
  static const MethodChannel _channel = MethodChannel('pipedit/storage');

  Future<bool> hasAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestAllFilesAccess() async {
    try {
      await _channel.invokeMethod<void>('requestAllFilesAccess');
    } on PlatformException {
      // Older Android versions do not have the all-files settings screen.
    }
  }

  Future<String?> externalStorageRoot() async {
    try {
      return await _channel.invokeMethod<String>('externalStorageRoot');
    } on PlatformException {
      return null;
    }
  }
}