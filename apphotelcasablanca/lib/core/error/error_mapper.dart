import 'package:dio/dio.dart';

import 'exceptions.dart';

/// Traduce los errores de Dio a nuestras excepciones de la capa data.
/// Aquí también se puede detectar el 23P01 (overbooking) que devuelva FastAPI.
class ErrorMapper {
  const ErrorMapper._();

  static Exception fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        return _fromResponse(e.response);
      case DioExceptionType.cancel:
        return const ServerException('Solicitud cancelada');
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const NetworkException();
    }
  }

  static Exception _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final message = _extractDetail(response?.data) ?? 'Error del servidor';

    return switch (status) {
      401 || 403 => UnauthorizedException(message),
      409 => ConflictException(message),
      _ => ServerException(message, statusCode: status),
    };
  }

  /// FastAPI suele devolver el error en {"detail": "..."}.
  static String? _extractDetail(Object? data) {
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) return first['msg'].toString();
      }
    }
    return null;
  }
}