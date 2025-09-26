import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/result/app_result.dart';
import '../../../core/storage/browser_storage.dart';
import '../../../core/utils/uri_utils.dart';
import '../../extract/controllers/extraction_controller.dart';

class BrowserController extends GetxController {
  BrowserController(this._extractionController, this._storage);

  final ExtractionController _extractionController;
  final BrowserStorage _storage;

  final TextEditingController urlController = TextEditingController();
  final Rxn<Uri> currentUrl = Rxn<Uri>();
  final RxnString validationError = RxnString();
  final RxBool isLoading = false.obs;
  final RxBool showControls = true.obs;
  final RxList<Uri> favorites = <Uri>[].obs;
  final RxBool isCurrentBookmarked = false.obs;

  WebViewController? _webViewController;
  Worker? _currentUrlWorker;
  Uri? _pendingInitialUrl;

  @override
  void onInit() {
    super.onInit();
    _currentUrlWorker = ever<Uri?>(currentUrl, _handleCurrentUrlChanged);
    _initializeState();
  }

  Future<void> _initializeState() async {
    try {
      final storedFavorites = await _storage.loadFavorites();
      final normalizedFavorites = storedFavorites
          .map(UriUtils.normalize)
          .toSet()
          .toList()
        ..sort((a, b) => a.toString().compareTo(b.toString()));
      favorites.assignAll(normalizedFavorites);
      AppLogger.logInfo(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: '_initializeState',
        systemSection: 'browser',
        message: 'Restored ${favorites.length} favorite URLs',
      );

      final lastVisited = await _storage.loadLastVisited();
      if (lastVisited != null) {
        final normalized = UriUtils.normalize(lastVisited);
        _pendingInitialUrl = normalized;
        currentUrl.value = normalized;
        urlController.text = normalized.toString();
        AppLogger.logInfo(
          filename: 'lib/features/browser/controllers/browser_controller.dart',
          classname: 'BrowserController',
          function: '_initializeState',
          systemSection: 'browser',
          message: 'Restored last visited URL $normalized',
        );
      }
    } catch (error, stackTrace) {
      AppLogger.logError(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: '_initializeState',
        systemSection: 'browser',
        message: 'Failed to restore browser state',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void attachWebViewController(WebViewController controller) {
    _webViewController = controller;
    AppLogger.logInfo(
      filename: 'lib/features/browser/controllers/browser_controller.dart',
      classname: 'BrowserController',
      function: 'attachWebViewController',
      systemSection: 'browser',
      message: 'Attached WebViewController instance',
    );

    final initialUrl = _pendingInitialUrl;
    if (initialUrl != null) {
      _pendingInitialUrl = null;
      unawaited(_loadInitialUrl(controller, initialUrl));
    }
  }

  Future<void> _loadInitialUrl(
    WebViewController controller,
    Uri url,
  ) async {
    try {
      AppLogger.logInfo(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: '_loadInitialUrl',
        systemSection: 'browser',
        message: 'Loading restored URL $url',
        method: 'GET',
      );
      await controller.loadRequest(url);
    } catch (error, stackTrace) {
      AppLogger.logError(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: '_loadInitialUrl',
        systemSection: 'browser',
        message: 'Failed to load restored URL $url',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
    final target = UriUtils.normalize(Uri.parse(normalized));
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

  void updateCurrentUrlFromWebView(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null) {
      AppLogger.logDebug(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: 'updateCurrentUrlFromWebView',
        systemSection: 'browser',
        message: 'Ignored malformed URL reported by web view: $url',
      );
      return;
    }

    final scheme = parsed.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      AppLogger.logDebug(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: 'updateCurrentUrlFromWebView',
        systemSection: 'browser',
        message: 'Ignored non-http URL reported by web view: $url',
      );
      return;
    }

    currentUrl.value = UriUtils.normalize(parsed);
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

  Future<void> toggleBookmark() async {
    final url = currentUrl.value;
    if (url == null) {
      AppLogger.logDebug(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: 'toggleBookmark',
        systemSection: 'browser',
        message: 'Ignoring bookmark toggle with no active URL',
      );
      return;
    }

    final normalized = UriUtils.normalize(url);
    final exists = favorites.any((uri) => uri == normalized);
    if (exists) {
      favorites.removeWhere((uri) => uri == normalized);
      isCurrentBookmarked.value = false;
      AppLogger.logInfo(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: 'toggleBookmark',
        systemSection: 'browser',
        message: 'Removed favorite URL $normalized',
      );
    } else {
      favorites.add(normalized);
      favorites.sort((a, b) => a.toString().compareTo(b.toString()));
      isCurrentBookmarked.value = true;
      AppLogger.logInfo(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: 'toggleBookmark',
        systemSection: 'browser',
        message: 'Added favorite URL $normalized',
      );
    }

    await _persistFavorites();
  }

  Future<void> openFromFavorites(Uri target) async {
    final normalized = UriUtils.normalize(target);
    urlController.text = normalized.toString();
    currentUrl.value = normalized;

    final controller = _webViewController;
    if (controller == null) {
      _pendingInitialUrl = normalized;
      AppLogger.logDebug(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: 'openFromFavorites',
        systemSection: 'browser',
        message: 'Deferring load of $normalized until WebView is ready',
      );
      return;
    }

    try {
      AppLogger.logInfo(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: 'openFromFavorites',
        systemSection: 'browser',
        message: 'Loading favorite URL $normalized',
        method: 'GET',
      );
      isLoading.value = true;
      await controller.loadRequest(normalized);
    } catch (error, stackTrace) {
      AppLogger.logError(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: 'openFromFavorites',
        systemSection: 'browser',
        message: 'Failed to load favorite URL $normalized',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _persistFavorites() async {
    try {
      await _storage.saveFavorites(List<Uri>.from(favorites));
    } catch (error, stackTrace) {
      AppLogger.logError(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: '_persistFavorites',
        systemSection: 'browser',
        message: 'Failed to persist favorite URLs',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _handleCurrentUrlChanged(Uri? uri) async {
    if (uri == null) {
      isCurrentBookmarked.value = false;
      try {
        await _storage.saveLastVisited(null);
      } catch (error, stackTrace) {
        AppLogger.logError(
          filename: 'lib/features/browser/controllers/browser_controller.dart',
          classname: 'BrowserController',
          function: '_handleCurrentUrlChanged',
          systemSection: 'browser',
          message: 'Failed to clear last visited URL',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return;
    }

    final normalized = UriUtils.normalize(uri);
    final bookmarked = favorites.any((item) => item == normalized);
    isCurrentBookmarked.value = bookmarked;

    try {
      await _storage.saveLastVisited(normalized);
    } catch (error, stackTrace) {
      AppLogger.logError(
        filename: 'lib/features/browser/controllers/browser_controller.dart',
        classname: 'BrowserController',
        function: '_handleCurrentUrlChanged',
        systemSection: 'browser',
        message: 'Failed to persist last visited URL $normalized',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
    _currentUrlWorker?.dispose();
    urlController.dispose();
    super.onClose();
  }
}
