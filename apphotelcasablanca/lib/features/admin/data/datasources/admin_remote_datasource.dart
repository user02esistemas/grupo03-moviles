// CONTRATO FASTAPI (todos requieren rol recepcionista/administrador; se valida
// en el backend a partir del JWT).
//
// GET   /admin/dashboard
//   -> { "reservas_activas": 8, "checkins_hoy": 3, "ingresos_hoy": "1520.00",
//        "habitaciones_disponibles": 5 }
// GET   /admin/reservas?estado=<id_estado_reserva opcional>
//   -> [ { id_reserva, codigo_reserva, cliente_nombre, numero_habitacion,
//          tipo_nombre, fecha_ingreso, fecha_salida, cantidad_personas,
//          monto_total, id_estado_reserva }, ... ]
// PATCH /admin/reservas/{id}/estado   body { "id_estado_reserva": 2 }
// GET   /admin/habitaciones
//   -> [ { id_habitacion, numero_habitacion, tipo_nombre, precio_noche,
//          capacidad, id_estado_habitacion }, ... ]
// PATCH /admin/habitaciones/{id}/estado  body { "id_estado_habitacion": 4 }
// GET   /admin/pagos?desde=YYYY-MM-DD&hasta=YYYY-MM-DD
//   -> { "total_ingresos": "1520.00", "cantidad_pagos": 4,
//        "pagos": [ { id_pago, codigo_reserva, cliente_nombre, monto,
//                     id_metodo_pago, id_estado_pago, fecha_pago }, ... ] }
import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/utils/formatters.dart';
import '../models/admin_models.dart';

abstract interface class AdminRemoteDataSource {
  Future<ResumenDiaModel> resumenDia();
  Future<List<ReservaAdminModel>> reservas({int? idEstado});
  Future<void> cambiarEstadoReserva(int idReserva, int idEstado);
  Future<List<HabitacionAdminModel>> habitaciones();
  Future<void> cambiarEstadoHabitacion(int idHabitacion, int idEstado);
  Future<ReportePagosModel> reportePagos({DateTime? desde, DateTime? hasta});
}

class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  const AdminRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<ResumenDiaModel> resumenDia() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>(ApiEndpoints.adminDashboard);
      return ResumenDiaModel.fromJson(res.data!);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<List<ReservaAdminModel>> reservas({int? idEstado}) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        ApiEndpoints.adminReservas,
        queryParameters: idEstado != null ? {'estado': idEstado} : null,
      );
      return (res.data ?? [])
          .map((e) => ReservaAdminModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<void> cambiarEstadoReserva(int idReserva, int idEstado) async {
    try {
      await _dio.patch<dynamic>(
        ApiEndpoints.adminReservaEstado(idReserva),
        data: {'id_estado_reserva': idEstado},
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<List<HabitacionAdminModel>> habitaciones() async {
    try {
      final res =
          await _dio.get<List<dynamic>>(ApiEndpoints.adminHabitaciones);
      return (res.data ?? [])
          .map((e) => HabitacionAdminModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<void> cambiarEstadoHabitacion(int idHabitacion, int idEstado) async {
    try {
      await _dio.patch<dynamic>(
        ApiEndpoints.adminHabitacionEstado(idHabitacion),
        data: {'id_estado_habitacion': idEstado},
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<ReportePagosModel> reportePagos({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (desde != null) query['desde'] = Formatters.fechaApi(desde);
      if (hasta != null) query['hasta'] = Formatters.fechaApi(hasta);
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminReportePagos,
        queryParameters: query.isEmpty ? null : query,
      );
      return ReportePagosModel.fromJson(res.data!);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}