import 'package:get/get.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/storage/settings_storage.dart';
import '../models/settings_state.dart';

class SettingsController extends GetxController {
  SettingsController(this._storage);

  final SettingsStorage _storage;

  final Rx<SettingsState> state = SettingsState.initial().obs;
  final RxBool isReady = false.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    AppLogger.logInfo(
      filename: 'lib/features/settings/controllers/settings_controller.dart',
      classname: 'SettingsController',
      function: '_load',
      systemSection: 'settings',
      message: 'Loading persisted settings',
    );
    try {
      final stored = await _storage.load();
      if (stored != null) {
        state.value = stored;
      }
      isReady.value = true;
    } catch (error, stackTrace) {
      AppLogger.logError(
        filename: 'lib/features/settings/controllers/settings_controller.dart',
        classname: 'SettingsController',
        function: '_load',
        systemSection: 'settings',
        message: 'Failed to load settings',
        error: error,
        stackTrace: stackTrace,
      );
      isReady.value = true;
    }
  }

  Future<void> updateSettings(SettingsState newState) async {
    state.value = newState;
    await _storage.save(newState);
    AppLogger.logInfo(
      filename: 'lib/features/settings/controllers/settings_controller.dart',
      classname: 'SettingsController',
      function: 'updateSettings',
      systemSection: 'settings',
      message: 'Persisted settings update',
    );
  }

  Future<void> setMinImageBytes(int value) => updateSettings(
        state.value.copyWith(minImageBytes: value),
      );

  Future<void> toggleDesktopUserAgent(bool enabled) => updateSettings(
        state.value.copyWith(useDesktopUserAgent: enabled),
      );

  Future<void> setConcurrentDownloads(int value) => updateSettings(
        state.value.copyWith(concurrentDownloads: value),
      );

  Future<void> toggleSvg(bool enabled) => updateSettings(
        state.value.copyWith(includeSvg: enabled),
      );

  Future<void> toggleGif(bool enabled) => updateSettings(
        state.value.copyWith(includeGif: enabled),
      );

  Future<void> toggleAutoplayThumbnails(bool enabled) => updateSettings(
        state.value.copyWith(includeAutoplayThumbnails: enabled),
      );

  Future<void> setImageSaveDirectory(String? path) => updateSettings(
        state.value.copyWith(imageSaveDirectory: path),
      );

  Future<void> setVideoSaveDirectory(String? path) => updateSettings(
        state.value.copyWith(videoSaveDirectory: path),
      );
}
