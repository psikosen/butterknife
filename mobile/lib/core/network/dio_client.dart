import 'package:dio/dio.dart';

import '../logging/app_logger.dart';

class DioClientFactory {
  const DioClientFactory();

  Dio create() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent':
              'ButterKnife/0.1 (+https://github.com/butterknife-mobile) Flutter',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          AppLogger.logDebug(
            filename: 'lib/core/network/dio_client.dart',
            classname: 'DioClientFactory',
            function: 'onRequest',
            systemSection: 'network',
            message: 'HTTP ${options.method} ${options.uri}',
            method: options.method,
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          AppLogger.logDebug(
            filename: 'lib/core/network/dio_client.dart',
            classname: 'DioClientFactory',
            function: 'onResponse',
            systemSection: 'network',
            message:
                'HTTP ${response.requestOptions.method} ${response.requestOptions.uri} => ${response.statusCode}',
            method: response.requestOptions.method,
            dbPhase: 'none',
          );
          handler.next(response);
        },
        onError: (error, handler) {
          AppLogger.logError(
            filename: 'lib/core/network/dio_client.dart',
            classname: 'DioClientFactory',
            function: 'onError',
            systemSection: 'network',
            message:
                'HTTP ${error.requestOptions.method} ${error.requestOptions.uri} failed',
            error: error,
            stackTrace: error.stackTrace,
            method: error.requestOptions.method,
          );
          handler.next(error);
        },
      ),
    );

    return dio;
  }
}
