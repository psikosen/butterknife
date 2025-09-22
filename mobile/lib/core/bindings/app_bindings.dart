import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../network/dio_client.dart';
import '../storage/settings_storage.dart';
import '../../features/browser/controllers/browser_controller.dart';
import '../../features/download/controllers/download_controller.dart';
import '../../features/extract/controllers/extraction_controller.dart';
import '../../features/settings/controllers/settings_controller.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<Dio>(() => const DioClientFactory().create(), fenix: true);

    Get.putAsync<SettingsController>(() async {
      final storage = await const SettingsStorageFactory().create();
      final controller = SettingsController(storage);
      return controller;
    }, permanent: true);

    Get.lazyPut<ExtractionController>(
      () => ExtractionController(Get.find<Dio>()),
      fenix: true,
    );
    Get.lazyPut<DownloadController>(
      () => DownloadController(Get.find<Dio>()),
      fenix: true,
    );
    Get.lazyPut<BrowserController>(
      () => BrowserController(Get.find<ExtractionController>()),
      fenix: true,
    );
  }
}
