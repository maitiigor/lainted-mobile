import 'package:dio/dio.dart';

/// Surfaces the backend's actual error message (set via ApiResponse::error)
/// instead of a generic hardcoded string, so failures are distinguishable -
/// e.g. "Incorrect code" vs "This code has expired" vs "Too many attempts".
String errorMessageFrom(Object error, {required String fallback}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
  }
  return fallback;
}
