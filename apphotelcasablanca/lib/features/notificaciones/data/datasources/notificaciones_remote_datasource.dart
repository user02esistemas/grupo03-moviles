// CONTRATO FASTAPI
// GET   /notificaciones            -> 200: [ NotificacionJSON, ... ] (del usuario, por JWT)
// PATCH /notificaciones/{id}/leer  -> 200/204
// PATCH /notificaciones/leer-todas -> 200/204
//
// NotificacionJSON = {
//   "id_notificacion": 10, "id_tipo_notificacion": 1,
//   "id_estado_notificacion": 1, "mensaje": "Tu reserva RSV-123 fue confirmada",
//   "fecha_envio": "2026-07-01T10:00:00Z"
// }
import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../models/notificacion_model.dart';

abstract interface class NotificacionesRemoteDataSource {
  Future<List<NotificacionModel>> obtener();
  Future<void> marcarLeida(int idNotificacion);
  Future<void> marcarTodasLeidas();
}

class NotificacionesRemoteDataSourceImpl
    implements NotificacionesRemoteDataSource {
  const NotificacionesRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<NotificacionModel>> obtener() async {
    try {
      final res = await _dio.get<List<dynamic>>(ApiEndpoints.notificaciones);
      return (res.data ?? [])
          .map((e) => NotificacionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<void> marcarLeida(int idNotificacion) async {
    try {
      await _dio.patch<dynamic>(ApiEndpoints.marcarLeida(idNotificacion));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<void> marcarTodasLeidas() async {
    try {
      await _dio.patch<dynamic>(ApiEndpoints.marcarTodasLeidas);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}