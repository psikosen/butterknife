import '../errors/app_error.dart';

sealed class AppResult<T> {
  const AppResult();

  bool get isSuccess => this is AppSuccess<T>;
  bool get isFailure => this is AppFailure<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(AppError error) failure,
  }) {
    if (this is AppSuccess<T>) {
      return success((this as AppSuccess<T>).value);
    }
    return failure((this as AppFailure<T>).error);
  }
}

final class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);

  final T value;
}

final class AppFailure<T> extends AppResult<T> {
  const AppFailure(this.error);

  final AppError error;
}
