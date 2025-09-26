import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';

abstract class BrowserStorage {
  Future<List<Uri>> loadFavorites();
  Future<void> saveFavorites(List<Uri> favorites);
  Future<Uri?> loadLastVisited();
  Future<void> saveLastVisited(Uri? uri);
}

class SharedPreferencesBrowserStorage implements BrowserStorage {
  SharedPreferencesBrowserStorage(this._preferences);

  final SharedPreferences _preferences;

  static const _favoritesKey = 'browser_favorites';
  static const _lastVisitedKey = 'browser_last_url';

  @override
  Future<List<Uri>> loadFavorites() async {
    final stored = _preferences.getStringList(_favoritesKey);
    if (stored == null) {
      return const [];
    }

    final uris = <Uri>[];
    for (final entry in stored) {
      try {
        uris.add(Uri.parse(entry));
      } catch (_) {
        AppLogger.logError(
          filename: 'lib/core/storage/browser_storage.dart',
          classname: 'SharedPreferencesBrowserStorage',
          function: 'loadFavorites',
          systemSection: 'browser',
          message: 'Skipped invalid favorite entry',
          error: entry,
        );
      }
    }
    return uris;
  }

  @override
  Future<void> saveFavorites(List<Uri> favorites) async {
    final encoded = favorites.map((uri) => uri.toString()).toList(growable: false);
    await _preferences.setStringList(_favoritesKey, encoded);
  }

  @override
  Future<Uri?> loadLastVisited() async {
    final stored = _preferences.getString(_lastVisitedKey);
    if (stored == null) {
      return null;
    }
    try {
      return Uri.parse(stored);
    } catch (error) {
      AppLogger.logError(
        filename: 'lib/core/storage/browser_storage.dart',
        classname: 'SharedPreferencesBrowserStorage',
        function: 'loadLastVisited',
        systemSection: 'browser',
        message: 'Failed to parse stored last visited URL',
        error: error,
      );
      return null;
    }
  }

  @override
  Future<void> saveLastVisited(Uri? uri) async {
    if (uri == null) {
      await _preferences.remove(_lastVisitedKey);
      return;
    }
    await _preferences.setString(_lastVisitedKey, uri.toString());
  }
}

class InMemoryBrowserStorage implements BrowserStorage {
  List<Uri> _favorites = const [];
  Uri? _lastVisited;

  @override
  Future<List<Uri>> loadFavorites() async => _favorites;

  @override
  Future<void> saveFavorites(List<Uri> favorites) async {
    _favorites = List<Uri>.from(favorites);
  }

  @override
  Future<Uri?> loadLastVisited() async => _lastVisited;

  @override
  Future<void> saveLastVisited(Uri? uri) async {
    _lastVisited = uri;
  }
}

class BrowserStorageFactory {
  const BrowserStorageFactory();

  Future<BrowserStorage> create() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return SharedPreferencesBrowserStorage(preferences);
    } catch (error, stackTrace) {
      AppLogger.logError(
        filename: 'lib/core/storage/browser_storage.dart',
        classname: 'BrowserStorageFactory',
        function: 'create',
        systemSection: 'browser',
        message: 'Falling back to in-memory browser storage',
        error: error,
        stackTrace: stackTrace,
      );
      return InMemoryBrowserStorage();
    }
  }
}
