import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';

/// Fábrica del cliente Dio configurado contra FastAPI.
class DioClient {
  const DioClient._();

  static Dio create(SecureStorage storage) {
    final baseUrl = Env.apiBaseUrl;

    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    );

    final dio = Dio(options);

    // Dio separado (sin AuthInterceptor) usado por el refresh, para no
    // provocar recursión al renovar el token.
    final refreshDio = Dio(options);

    dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        refreshDio: refreshDio,
        baseUrl: baseUrl,
      ),
    );

    // Log de requests solo en debug.
    assert(() {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
      return true;
    }());

    return dio;
  }
}