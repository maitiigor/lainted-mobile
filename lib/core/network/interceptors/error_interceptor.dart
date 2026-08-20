import 'package:dio/dio.dart';

/// A small typed exception surfaced to callers instead of raw [DioException].
class ApiException implements Exception {
  ApiException({required this.message, this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// Machine-readable error code, when the backend sends one - currently
  /// only `account_restricted` (see EnsureAccountIsActive on the
  /// backend). Distinct from statusCode==403 alone, since other 403s
  /// (e.g. the seller-profile gate on listing creation) are NOT this.
  final String? code;

  bool get isAccountRestricted => code == 'account_restricted';

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Maps [DioException]s to [ApiException] with a user-friendly message.
class ErrorInterceptor extends Interceptor {
  ErrorInterceptor({this.onAccountRestricted});

  /// Fired once per suspended/banned response - the interceptor has no
  /// BuildContext/navigator of its own, so the actual session-clear +
  /// redirect-to-login lives wherever this callback is wired up
  /// (dio_provider.dart), not here.
  final void Function()? onAccountRestricted;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;
    final serverMessage = data is Map ? data['message'] as String? : null;
    final code = data is Map ? data['code'] as String? : null;

    final message = serverMessage ?? _defaultMessageFor(err);
    final apiException = ApiException(message: message, statusCode: statusCode, code: code);

    if (apiException.isAccountRestricted) {
      onAccountRestricted?.call();
    }

    handler.next(err.copyWith(error: apiException));
  }

  String _defaultMessageFor(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please check your internet and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      case DioExceptionType.badResponse:
        return 'Something went wrong. Please try again.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return 'Unexpected error occurred.';
    }
  }
}
