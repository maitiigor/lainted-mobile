import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';

/// Builds the app's shared [Dio] instance: base URL, timeouts, auth token
/// injection, error mapping, and (debug-only) request/response logging.
class DioClient {
  static Dio create({FlutterSecureStorage? secureStorage, void Function()? onAccountRestricted}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(secureStorage ?? const FlutterSecureStorage()),
      ErrorInterceptor(onAccountRestricted: onAccountRestricted),
      if (kDebugMode)
        LogInterceptor(requestBody: true, responseBody: true),
    ]);

    return dio;
  }
}
