sealed class AppError implements Exception {
  const AppError(this.message, [this.stackTrace]);

  final String message;
  final StackTrace? stackTrace;

  Map<String, dynamic> toJson();

  @override
  String toString() => message;
}

final class NetworkError extends AppError {
  const NetworkError(String message, {this.statusCode, StackTrace? stackTrace})
      : super(message, stackTrace);

  final int? statusCode;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'network',
        'message': message,
        'statusCode': statusCode,
        'stackTrace': stackTrace?.toString(),
      };
}

final class ValidationError extends AppError {
  const ValidationError(String message, {StackTrace? stackTrace})
      : super(message, stackTrace);

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'validation',
        'message': message,
        'stackTrace': stackTrace?.toString(),
      };
}

final class UnknownError extends AppError {
  const UnknownError(String message, {Object? cause, StackTrace? stackTrace})
      : _cause = cause,
        super(message, stackTrace);

  final Object? _cause;

  Object? get cause => _cause;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'unknown',
        'message': message,
        'cause': _cause?.toString(),
        'stackTrace': stackTrace?.toString(),
      };
}
