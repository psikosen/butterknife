import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';
import '../../features/settings/models/settings_state.dart';

abstract class SettingsStorage {
  Future<SettingsState?> load();
  Future<void> save(SettingsState state);
}

class SharedPreferencesSettingsStorage implements SettingsStorage {
  SharedPreferencesSettingsStorage(this._preferences);

  final SharedPreferences _preferences;

  static const _key = 'butterknife_settings';

  @override
  Future<SettingsState?> load() async {
    final jsonString = _preferences.getString(_key);
    if (jsonString == null) {
      return null;
    }
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    return SettingsState.fromJson(decoded);
  }

  @override
  Future<void> save(SettingsState state) async {
    await _preferences.setString(_key, jsonEncode(state.toJson()));
  }
}

class InMemorySettingsStorage implements SettingsStorage {
  SettingsState? _state;

  @override
  Future<SettingsState?> load() async => _state;

  @override
  Future<void> save(SettingsState state) async {
    _state = state;
  }
}

class SettingsStorageFactory {
  const SettingsStorageFactory();

  Future<SettingsStorage> create() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return SharedPreferencesSettingsStorage(preferences);
    } catch (error, stackTrace) {
      AppLogger.logError(
        filename: 'lib/core/storage/settings_storage.dart',
        classname: 'SettingsStorageFactory',
        function: 'create',
        systemSection: 'settings',
        message: 'Falling back to in-memory settings storage',
        error: error,
        stackTrace: stackTrace,
      );
      return InMemorySettingsStorage();
    }
  }
}
