import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/result/app_result.dart';
import '../../../core/utils/uri_utils.dart';
import '../../extract/controllers/extraction_controller.dart';

class BrowserController extends GetxController {
  BrowserController(this._extractionController);

  final ExtractionController _extractionController;

  final TextEditingController urlController = TextEditingController();
  final Rxn<Uri> currentUrl = Rxn<Uri>();
  final RxnString validationError = RxnString();
  final RxBool isLoading = false.obs;
  final RxBool showControls = true.obs;

  WebViewController? _webViewController;

  void attachWebViewController(WebViewController controller) {
    _webViewController = controller;
    AppLogger.logInfo(
      filename: 'lib/features/browser/controllers/browser_controller.dart',
      classname: 'BrowserController',
      function: 'attachWebViewController',
      systemSection: 'browser',
      message: 'Attached WebViewController instance',
    );
  }

  Future<void> openCurrentUrl() async {
    final input = urlController.text.trim();
    if (input.isEmpty) {
      validationError.value = 'Enter a page URL to open';
      return;
    }

    final normalized = _normalizeInput(input);
    if (normalized == null) {
      validationError.value = 'Provide a valid http or https URL';
      return;
    }

    validationError.value = null;
    final target = Uri.parse(normalized);
    currentUrl.value = target;
    final controller = _webViewController;
    if (controller == null) {
      throw StateError('WebViewController has not been attached yet.');
    }
    AppLogger.logInfo(
      filename: 'lib/features/browser/controllers/browser_controller.dart',
      classname: 'BrowserController',
      function: 'openCurrentUrl',
      systemSection: 'browser',
      message: 'Loading URL $target',
      method: 'GET',
    );
    isLoading.value = true;
    await controller.loadRequest(target);
    isLoading.value = false;
  }

  Future<AppResult<void>> processCurrentPage() async {
    final controller = _webViewController;
    final url = currentUrl.value;
    if (controller == null || url == null) {
      final error = ValidationError('Open a page before processing');
      _extractionController.recordError(error);
      return AppFailure<void>(error);
    }
    AppLogger.logInfo(
      filename: 'lib/features/browser/controllers/browser_controller.dart',
      classname: 'BrowserController',
      function: 'processCurrentPage',
      systemSection: 'browser',
      message: 'Starting extraction for $url',
    );
    return _extractionController.processPage(url, controller);
  }

  void toggleControlsVisibility() {
    final newVisibility = !showControls.value;
    showControls.value = newVisibility;
    AppLogger.logInfo(
      filename: 'lib/features/browser/controllers/browser_controller.dart',
      classname: 'BrowserController',
      function: 'toggleControlsVisibility',
      systemSection: 'browser',
      message: newVisibility
          ? 'Showing browser controls'
          : 'Hiding browser controls',
    );
  }

  String? _normalizeInput(String input) {
    final withScheme = input.contains('://') ? input : 'https://$input';
    try {
      return UriUtils.normalize(Uri.parse(withScheme)).toString();
    } on FormatException {
      return null;
    }
  }

  @override
  void onClose() {
    urlController.dispose();
    super.onClose();
  }
}
