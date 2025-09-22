import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/result/app_result.dart';
import '../../../shared/models/media_item.dart';

enum DownloadPhase { queued, inProgress, completed, failed }

class DownloadProgress {
  const DownloadProgress({
    required this.phase,
    required this.progress,
    this.error,
  });

  const DownloadProgress.queued()
      : phase = DownloadPhase.queued,
        progress = 0,
        error = null;

  const DownloadProgress.inProgress(double progressValue)
      : phase = DownloadPhase.inProgress,
        progress = progressValue,
        error = null;

  const DownloadProgress.completed()
      : phase = DownloadPhase.completed,
        progress = 1,
        error = null;

  const DownloadProgress.failed(AppError errorValue)
      : phase = DownloadPhase.failed,
        progress = 0,
        error = errorValue;

  final DownloadPhase phase;
  final double progress;
  final AppError? error;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'phase': phase.name,
        'progress': progress,
        'error': error?.toJson(),
      };
}

class DownloadController extends GetxController {
  DownloadController(this._dio);

  final Dio _dio;

  final RxMap<String, DownloadProgress> taskProgress = <String, DownloadProgress>{}.obs;
  final RxList<MediaItem> completedDownloads = <MediaItem>[].obs;

  Future<AppResult<MediaItem>> download(MediaItem item) async {
    taskProgress[item.id] = const DownloadProgress.queued();
    AppLogger.logInfo(
      filename: 'lib/features/download/controllers/download_controller.dart',
      classname: 'DownloadController',
      function: 'download',
      systemSection: 'download',
      message: 'Starting download for ${item.normalizedUrl}',
      method: 'GET',
    );
    try {
      final response = await _dio.getUri<List<int>>(
        item.normalizedUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            taskProgress[item.id] = const DownloadProgress.inProgress(0);
            return;
          }
          taskProgress[item.id] = DownloadProgress.inProgress(received / total);
        },
      );
      final bytes = Uint8List.fromList(response.data ?? <int>[]);
      final updatedItem = item.copyWith(
        bytes: bytes,
        contentLength: bytes.length,
      );
      completedDownloads.add(updatedItem);
      taskProgress[item.id] = const DownloadProgress.completed();
      AppLogger.logInfo(
        filename: 'lib/features/download/controllers/download_controller.dart',
        classname: 'DownloadController',
        function: 'download',
        systemSection: 'download',
        message: 'Completed download for ${item.normalizedUrl}',
      );
      return AppSuccess<MediaItem>(updatedItem);
    } on DioException catch (error, stackTrace) {
      final networkError = NetworkError(
        'Failed to download ${item.normalizedUrl}',
        statusCode: error.response?.statusCode,
        stackTrace: stackTrace,
      );
      taskProgress[item.id] = DownloadProgress.failed(networkError);
      AppLogger.logError(
        filename: 'lib/features/download/controllers/download_controller.dart',
        classname: 'DownloadController',
        function: 'download',
        systemSection: 'download',
        message: networkError.message,
        error: error,
        stackTrace: stackTrace,
      );
      return AppFailure<MediaItem>(networkError);
    } catch (error, stackTrace) {
      final appError = UnknownError(
        'Unexpected error during download',
        cause: error,
        stackTrace: stackTrace,
      );
      taskProgress[item.id] = DownloadProgress.failed(appError);
      AppLogger.logError(
        filename: 'lib/features/download/controllers/download_controller.dart',
        classname: 'DownloadController',
        function: 'download',
        systemSection: 'download',
        message: appError.message,
        error: error,
        stackTrace: stackTrace,
      );
      return AppFailure<MediaItem>(appError);
    }
  }

  Future<List<AppResult<MediaItem>>> downloadAll(Iterable<MediaItem> items) async {
    final results = <AppResult<MediaItem>>[];
    for (final item in items) {
      final result = await download(item);
      results.add(result);
    }
    return results;
  }
}
