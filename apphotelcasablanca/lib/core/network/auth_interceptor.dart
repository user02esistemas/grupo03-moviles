import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../storage/secure_storage.dart';

/// Inyecta el access token en cada request y, ante un 401, intenta refrescar
/// el token una sola vez y reintenta la petición original.
class AuthInterceptor extends QueuedInterceptorsWrapper {
  AuthInterceptor({
    required this.storage,
    required this.refreshDio,
    required this.baseUrl,
  });

  final SecureStorage storage;

  /// Dio "limpio" (sin este interceptor) para llamar a /auth/refresh y evitar
  /// un bucle infinito de refresh.
  final Dio refreshDio;
  final String baseUrl;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Endpoints públicos: no adjuntar token.
    final isPublic = options.path.contains(ApiEndpoints.login) ||
        options.path.contains(ApiEndpoints.register) ||
        options.path.contains(ApiEndpoints.loginGoogle) ||
        options.path.contains(ApiEndpoints.refresh);

    if (!isPublic) {
      final token = await storage.accessToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final is401 = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (!is401 || alreadyRetried) {
      return handler.next(err);
    }

    final refreshToken = await storage.refreshToken;
    if (refreshToken == null) {
      await storage.clear();
      return handler.next(err);
    }

    try {
      final response = await refreshDio.post<Map<String, dynamic>>(
        '$baseUrl${ApiEndpoints.refresh}',
        data: {'refresh_token': refreshToken},
      );

      final newAccess = response.data!['access_token'] as String;
      final newRefresh =
          (response.data!['refresh_token'] as String?) ?? refreshToken;
      await storage.saveTokens(accessToken: newAccess, refreshToken: newRefresh);

      // Reintentar la petición original con el nuevo token.
      final options = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newAccess'
        ..extra['retried'] = true;

      final retry = await refreshDio.fetch<dynamic>(options);
      return handler.resolve(retry);
    } catch (_) {
      await storage.clear();
      return handler.next(err);
    }
  }
}