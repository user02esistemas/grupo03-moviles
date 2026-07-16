// UBICACIÓN: lib/features/habitaciones/data/datasources/habitaciones_remote_datasource.dart
//
// CONTRATO ESPERADO DE FASTAPI
// GET /habitaciones?fecha_inicio=YYYY-MM-DD&fecha_fin=YYYY-MM-DD&personas=N
//   -> 200: [ HabitacionJSON, ... ]   (si hay fechas, solo las disponibles)
// GET /habitaciones/{id}
//   -> 200: HabitacionJSON
//
// HabitacionJSON = {
//   "id_habitacion": 12,
//   "numero_habitacion": "101",
//   "descripcion": "Vista al jardín",
//   "precio_noche": "180.00",          // número o string; se parsea igual
//   "capacidad": 2,
//   "id_estado_habitacion": 1,
//   "tipo":      { "id_tipo": 1, "nombre_tipo": "Doble", "descripcion": "..." },
//   "servicios": [ { "id_servicio": 1, "nombre": "WiFi", "descripcion": null }, ... ],
//   "imagenes":  [ { "id_imagen": 5, "url": "https://.../101.jpg", "orden": 0, "es_principal": true }, ... ]
// }
import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/filtro_busqueda.dart';
import '../models/habitacion_model.dart';

abstract interface class HabitacionesRemoteDataSource {
  Future<List<HabitacionModel>> obtenerHabitaciones(FiltroBusqueda filtro);
  Future<HabitacionModel> obtenerDetalle(int idHabitacion);
}

class HabitacionesRemoteDataSourceImpl implements HabitacionesRemoteDataSource {
  const HabitacionesRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<HabitacionModel>> obtenerHabitaciones(
    FiltroBusqueda filtro,
  ) async {
    try {
      final query = <String, dynamic>{'personas': filtro.personas};
      if (filtro.tieneFechas) {
        query['fecha_inicio'] = Formatters.fechaApi(filtro.fechaInicio!);
        query['fecha_fin'] = Formatters.fechaApi(filtro.fechaFin!);
      }

      final res = await _dio.get<List<dynamic>>(
        ApiEndpoints.habitaciones,
        queryParameters: query,
      );

      return (res.data ?? [])
          .map((e) => HabitacionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<HabitacionModel> obtenerDetalle(int idHabitacion) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.habitacion(idHabitacion),
      );
      return HabitacionModel.fromJson(res.data!);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}