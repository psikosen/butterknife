import 'package:flutter/material.dart';

import 'app.dart';
import 'core/logging/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.logInfo(
    filename: 'lib/main.dart',
    classname: 'main',
    function: 'main',
    systemSection: 'bootstrap',
    message: 'Starting Butter Knife Flutter application',
  );
  runApp(const ButterKnifeApp());
}
