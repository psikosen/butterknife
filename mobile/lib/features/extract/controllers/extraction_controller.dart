import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/result/app_result.dart';
import '../../../core/utils/uri_utils.dart';
import '../../../shared/models/extraction_result.dart';
import '../../../shared/models/media_item.dart';

class ExtractionController extends GetxController {
  ExtractionController(this._dio);

  final Dio _dio;

  final RxBool isProcessing = false.obs;
  final RxList<MediaItem> extractedItems = <MediaItem>[].obs;
  final Rx<SkippedStats> skippedStats = const SkippedStats().obs;
  final Rxn<AppError> lastError = Rxn<AppError>();

  Future<AppResult<void>> processPage(
    Uri pageUrl,
    WebViewController webViewController,
  ) async {
    isProcessing.value = true;
    lastError.value = null;
    skippedStats.value = const SkippedStats();

    AppLogger.logInfo(
      filename: 'lib/features/extract/controllers/extraction_controller.dart',
      classname: 'ExtractionController',
      function: 'processPage',
      systemSection: 'extraction',
      message: 'Injecting DOM scanner for $pageUrl',
    );

    try {
      final rawResult = await webViewController.runJavaScriptReturningResult(_domScannerScript);
      final jsonPayload = _coerceResult(rawResult);
      final decoded = jsonDecode(jsonPayload) as Map<String, dynamic>;
      final candidates = decoded['images'] as List<dynamic>? ?? <dynamic>[];
      final mediaItems = <MediaItem>[];
      for (var index = 0; index < candidates.length; index++) {
        final candidate = candidates[index] as Map<String, dynamic>;
        final rawSrc = candidate['src'] as String?;
        if (rawSrc == null || rawSrc.isEmpty) {
          continue;
        }
        try {
          final resolved = UriUtils.resolveToAbsolute(rawSrc, pageUrl);
          mediaItems.add(
            MediaItem(
              id: candidate['id'] as String? ?? 'media-$index',
              type: _mediaTypeFromTag(candidate['tag'] as String? ?? 'img'),
              url: resolved,
              normalizedUrl: UriUtils.normalize(resolved),
              width: (candidate['width'] as num?)?.toInt(),
              height: (candidate['height'] as num?)?.toInt(),
              thumbnailUrl: _parseOptionalUri(candidate['poster'] as String?, pageUrl),
            ),
          );
        } on ArgumentError catch (error, stackTrace) {
          AppLogger.logError(
            filename: 'lib/features/extract/controllers/extraction_controller.dart',
            classname: 'ExtractionController',
            function: 'processPage',
            systemSection: 'extraction',
            message: 'Failed to resolve candidate URL: $rawSrc',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      final probedItems = <MediaItem>[];
      for (final item in mediaItems) {
        final probed = await _probeCandidate(item);
        probedItems.add(probed);
      }
      extractedItems.assignAll(probedItems);
      AppLogger.logInfo(
        filename: 'lib/features/extract/controllers/extraction_controller.dart',
        classname: 'ExtractionController',
        function: 'processPage',
        systemSection: 'extraction',
        message: 'Extracted ${probedItems.length} media candidates',
      );
      return AppSuccess<void>(null);
    } on Exception catch (error, stackTrace) {
      final appError = UnknownError('Failed to analyze page', cause: error, stackTrace: stackTrace);
      recordError(appError);
      return AppFailure<void>(appError);
    } finally {
      isProcessing.value = false;
    }
  }

  void recordError(AppError error) {
    lastError.value = error;
    AppLogger.logError(
      filename: 'lib/features/extract/controllers/extraction_controller.dart',
      classname: 'ExtractionController',
      function: 'recordError',
      systemSection: 'extraction',
      message: error.message,
      error: error,
      stackTrace: error.stackTrace,
    );
  }

  Future<MediaItem> _probeCandidate(MediaItem item) async {
    AppLogger.logDebug(
      filename: 'lib/features/extract/controllers/extraction_controller.dart',
      classname: 'ExtractionController',
      function: '_probeCandidate',
      systemSection: 'extraction',
      message: 'Probing ${item.normalizedUrl}',
      method: 'HEAD',
    );
    try {
      final response = await _dio.headUri(
        item.normalizedUrl,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final contentType = response.headers.value('content-type');
      final contentLengthHeader = response.headers.value('content-length');
      final contentLength = contentLengthHeader == null
          ? null
          : int.tryParse(contentLengthHeader);
      final type = _classifyByContentType(contentType, item.type);
      return item.copyWith(
        contentLength: contentLength,
        type: type,
      );
    } on DioException catch (error, stackTrace) {
      AppLogger.logError(
        filename: 'lib/features/extract/controllers/extraction_controller.dart',
        classname: 'ExtractionController',
        function: '_probeCandidate',
        systemSection: 'extraction',
        message: 'HEAD request failed for ${item.normalizedUrl}',
        error: error,
        stackTrace: stackTrace,
      );
      return item;
    } catch (error, stackTrace) {
      AppLogger.logError(
        filename: 'lib/features/extract/controllers/extraction_controller.dart',
        classname: 'ExtractionController',
        function: '_probeCandidate',
        systemSection: 'extraction',
        message: 'Unexpected error while probing ${item.normalizedUrl}',
        error: error,
        stackTrace: stackTrace,
      );
      return item;
    }
  }

  static String _coerceResult(Object? rawResult) {
    if (rawResult == null) {
      return '{}';
    }
    if (rawResult is String) {
      if (rawResult.startsWith('"') && rawResult.endsWith('"')) {
        return jsonDecode(rawResult) as String;
      }
      return rawResult;
    }
    return jsonEncode(rawResult);
  }

  static MediaType _mediaTypeFromTag(String tag) {
    switch (tag.toLowerCase()) {
      case 'video':
        return MediaType.video;
      default:
        return MediaType.image;
    }
  }

  static MediaType _classifyByContentType(String? contentType, MediaType fallback) {
    final normalized = contentType?.toLowerCase() ?? '';
    if (normalized.startsWith('image/')) {
      return MediaType.image;
    }
    if (normalized.startsWith('video/')) {
      return MediaType.video;
    }
    if (normalized.contains('mpegurl') || normalized.contains('mp2t')) {
      return MediaType.streaming;
    }
    return fallback;
  }

  void toggleSelection(String id) {
    final index = extractedItems.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    final current = extractedItems[index];
    extractedItems[index] = current.copyWith(isSelected: !current.isSelected);
    extractedItems.refresh();
  }

  void applyDownloadedItem(MediaItem item) {
    final index = extractedItems.indexWhere((element) => element.id == item.id);
    if (index == -1) {
      return;
    }
    extractedItems[index] = item;
    extractedItems.refresh();
  }

  List<MediaItem> get selectedItems =>
      extractedItems.where((item) => item.isSelected).toList(growable: false);

  static Uri? _parseOptionalUri(String? value, Uri base) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      return UriUtils.resolveToAbsolute(value, base);
    } on ArgumentError {
      return null;
    }
  }
}

const String _domScannerScript = r'''
(() => {
  const pickSrc = (element) => {
    if (!element) {
      return '';
    }
    if (element.currentSrc) {
      return element.currentSrc;
    }
    if (element.srcset) {
      const parts = element.srcset.split(',').map((item) => item.trim());
      if (parts.length > 0) {
        return parts[parts.length - 1].split(' ')[0];
      }
    }
    return element.src || '';
  };

  const images = Array.from(document.querySelectorAll('img, picture source, video')).map((element, index) => {
    let tag = element.tagName.toLowerCase();
    let src = '';
    let poster = '';
    let width = element.naturalWidth || element.videoWidth || element.clientWidth || 0;
    let height = element.naturalHeight || element.videoHeight || element.clientHeight || 0;

    if (tag === 'source') {
      const parent = element.parentElement;
      if (parent && parent.tagName.toLowerCase() === 'picture') {
        tag = 'img';
        src = pickSrc(element);
        width = parent.clientWidth;
        height = parent.clientHeight;
      }
    } else if (tag === 'video') {
      src = pickSrc(element.querySelector('source')) || element.currentSrc || element.src || '';
      poster = element.poster || '';
      width = element.videoWidth || element.clientWidth || 0;
      height = element.videoHeight || element.clientHeight || 0;
    } else {
      src = pickSrc(element);
    }

    return {
      id: `${tag}-${index}`,
      tag,
      src,
      poster,
      width,
      height,
    };
  });

  return JSON.stringify({ images });
})();
''';
