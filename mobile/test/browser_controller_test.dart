import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:butterknife_app/core/storage/browser_storage.dart';
import 'package:butterknife_app/core/utils/uri_utils.dart';
import 'package:butterknife_app/features/browser/controllers/browser_controller.dart';
import 'package:butterknife_app/features/extract/controllers/extraction_controller.dart';

class _MockExtractionController extends Mock implements ExtractionController {}

class _MockWebViewController extends Mock implements WebViewController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://fallback.test'));
  });

  late ExtractionController extractionController;
  late InMemoryBrowserStorage storage;
  late BrowserController controller;

  setUp(() {
    extractionController = _MockExtractionController();
    storage = InMemoryBrowserStorage();
    controller = BrowserController(extractionController, storage);
    controller.onInit();
  });

  tearDown(() {
    controller.onClose();
  });

  Future<void> _pumpController() async {
    await Future<void>.delayed(Duration.zero);
  }

  test('restores favorites and last visited URL on init', () async {
    await storage.saveFavorites([Uri.parse('https://example.com')]);
    await storage.saveLastVisited(Uri.parse('https://flutter.dev'));

    final restoredController = BrowserController(extractionController, storage);
    restoredController.onInit();
    await _pumpController();

    expect(restoredController.favorites.length, 1);
    expect(restoredController.favorites.first.toString(), 'https://example.com');
    expect(restoredController.currentUrl.value?.toString(), 'https://flutter.dev');
    expect(restoredController.urlController.text, 'https://flutter.dev');
    expect(restoredController.isCurrentBookmarked.value, isFalse);
    restoredController.onClose();
  });

  test('toggleBookmark adds and removes favorites and persists state', () async {
    controller.currentUrl.value = Uri.parse('https://example.com/path');
    await _pumpController();
    expect(controller.isCurrentBookmarked.value, isFalse);

    await controller.toggleBookmark();
    await _pumpController();
    expect(controller.isCurrentBookmarked.value, isTrue);
    expect(controller.favorites.map((uri) => uri.toString()),
        contains('https://example.com/path'));
    final storedAfterAdd = await storage.loadFavorites();
    expect(storedAfterAdd.map((uri) => uri.toString()),
        contains('https://example.com/path'));

    await controller.toggleBookmark();
    await _pumpController();
    expect(controller.isCurrentBookmarked.value, isFalse);
    final storedAfterRemove = await storage.loadFavorites();
    expect(storedAfterRemove, isEmpty);
  });

  test('updateCurrentUrlFromWebView ignores invalid and non-http URLs', () {
    controller.updateCurrentUrlFromWebView('not a url');
    expect(controller.currentUrl.value, isNull);

    controller.updateCurrentUrlFromWebView('about:blank');
    expect(controller.currentUrl.value, isNull);

    controller.updateCurrentUrlFromWebView('https://example.com/?b=2&a=1');
    expect(controller.currentUrl.value?.toString(),
        equals(UriUtils.normalize(Uri.parse('https://example.com/?b=2&a=1')).toString()));
  });

  test('openFromFavorites loads URL through web view when available', () async {
    final webView = _MockWebViewController();
    when(() => webView.loadRequest(any())).thenAnswer((_) async {});

    controller.attachWebViewController(webView);
    await controller.openFromFavorites(Uri.parse('https://example.com/?b=2&a=1'));

    final expected = UriUtils.normalize(Uri.parse('https://example.com/?b=2&a=1'));
    verify(() => webView.loadRequest(expected)).called(1);
    expect(controller.currentUrl.value, expected);
    expect(controller.urlController.text, expected.toString());
  });

  test('current URL changes persist the last visited URL', () async {
    final target = Uri.parse('https://flutter.dev/docs');
    controller.currentUrl.value = target;
    await _pumpController();

    final stored = await storage.loadLastVisited();
    expect(stored, UriUtils.normalize(target));
  });
}
