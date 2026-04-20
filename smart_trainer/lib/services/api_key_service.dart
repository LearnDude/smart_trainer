import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Stores the Claude API key in %APPDATA%\smart_trainer\api_key.
// The file is user-account-scoped; Windows prevents other users from reading it.
class ApiKeyService {
  Future<File> _keyFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'api_key'));
  }

  Future<String?> getApiKey() async {
    final file = await _keyFile();
    if (!file.existsSync()) return null;
    final value = file.readAsStringSync().trim();
    return value.isEmpty ? null : value;
  }

  Future<void> setApiKey(String key) async {
    final file = await _keyFile();
    await file.writeAsString(key.trim());
  }

  Future<void> deleteApiKey() async {
    final file = await _keyFile();
    if (file.existsSync()) await file.delete();
  }
}

final apiKeyServiceProvider = Provider((_) => ApiKeyService());
