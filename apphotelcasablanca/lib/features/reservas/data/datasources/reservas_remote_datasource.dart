// UBICACIÓN: lib/features/reservas/data/datasources/reservas_remote_datasource.dart
//
// CONTRATO ESPERADO DE FASTAPI
// POST  /reservas
//   body: { "id_habitacion": 12, "fecha_ingreso": "2026-07-15",
//           "fecha_salida": "2026-07-18", "cantidad_personas": 2 }
//   -> 201: ReservaJSON   (el back calcula monto_total y genera codigo_reserva)
//   -> 409: { "detail": "..." }  cuando las fechas se solapan (EXCLUDE)
// GET   /reservas/mias        -> 200: [ ReservaJSON, ... ]   (usa el JWT)
// PATCH /reservas/{id}/cancelar -> 200/204
//
// ReservaJSON = {
//   "id_reserva": 1, "codigo_reserva": "RSV-000123", "id_habitacion": 12,
//   "id_estado_reserva": 1, "fecha_ingreso": "2026-07-15",
//   "fecha_salida": "2026-07-18", "cantidad_personas": 2,
//   "monto_total": "540.00", "fecha_reserva": "2026-07-01T10:00:00Z",
//   "habitacion": { "numero_habitacion": "101", "tipo_nombre": "Doble",
//                   "imagen_url": "https://.../101.jpg" }
// }
import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/crear_reserva_params.dart';
import '../models/reserva_model.dart';

abstract interface class ReservasRemoteDataSource {
  Future<ReservaModel> crear(CrearReservaParams params);
  Future<List<ReservaModel>> misReservas();
  Future<void> cancelar(int idReserva);
}

class ReservasRemoteDataSourceImpl implements ReservasRemoteDataSource {
  const ReservasRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<ReservaModel> crear(CrearReservaParams p) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.reservas,
        data: {
          'id_habitacion': p.idHabitacion,
          'fecha_ingreso': Formatters.fechaApi(p.fechaIngreso),
          'fecha_salida': Formatters.fechaApi(p.fechaSalida),
          'cantidad_personas': p.cantidadPersonas,
        },
      );
      return ReservaModel.fromJson(res.data!);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<List<ReservaModel>> misReservas() async {
    try {
      final res = await _dio.get<List<dynamic>>(ApiEndpoints.reservasMias);
      return (res.data ?? [])
          .map((e) => ReservaModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<void> cancelar(int idReserva) async {
    try {
      await _dio.patch<dynamic>(ApiEndpoints.cancelarReserva(idReserva));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}