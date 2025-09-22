import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/bindings/app_bindings.dart';
import 'core/logging/app_logger.dart';
import 'features/browser/views/browser_view.dart';

class ButterKnifeApp extends StatelessWidget {
  const ButterKnifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.logInfo(
      filename: 'lib/app.dart',
      classname: 'ButterKnifeApp',
      function: 'build',
      systemSection: 'ui',
      message: 'Building root application widget',
    );
    return GetMaterialApp(
      title: 'Butter Knife',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      initialBinding: AppBindings(),
      home: const BrowserView(),
    );
  }
}
