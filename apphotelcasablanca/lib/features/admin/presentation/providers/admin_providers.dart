import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/infra_providers.dart';
import '../../../../core/enums/estado_habitacion.dart';
import '../../../../core/enums/estado_reserva.dart';
import '../../data/datasources/admin_remote_datasource.dart';
import '../../data/repositories/admin_repository_impl.dart';
import '../../domain/entities/habitacion_admin.dart';
import '../../domain/entities/reporte_pagos.dart';
import '../../domain/entities/reserva_admin.dart';
import '../../domain/entities/resumen_dia.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/admin_usecases.dart';

// -------------------- DI --------------------

final _remoteProvider = Provider<AdminRemoteDataSource>(
  (ref) => AdminRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final _repositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepositoryImpl(ref.watch(_remoteProvider)),
);

// -------------------- Datos --------------------

final resumenDiaProvider = FutureProvider<ResumenDia>((ref) async {
  final result = await ObtenerResumenDia(ref.watch(_repositoryProvider)).call();
  return result.fold((f) => throw f, (r) => r);
});

/// Filtro de estado para la lista de reservas del admin (null = todas).
final filtroEstadoReservaProvider = StateProvider<EstadoReserva?>((_) => null);

final reservasAdminProvider = FutureProvider<List<ReservaAdmin>>((ref) async {
  final estado = ref.watch(filtroEstadoReservaProvider);
  final result = await ObtenerReservasAdmin(ref.watch(_repositoryProvider))
      .call(estado: estado);
  return result.fold((f) => throw f, (l) => l);
});

final habitacionesAdminProvider =
    FutureProvider<List<HabitacionAdmin>>((ref) async {
  final result =
      await ObtenerHabitacionesAdmin(ref.watch(_repositoryProvider)).call();
  return result.fold((f) => throw f, (l) => l);
});

/// Rango del reporte de pagos (por defecto: hoy).
final rangoReporteProvider = StateProvider<DateTimeRange?>((_) => null);

final reportePagosProvider = FutureProvider<ReportePagos>((ref) async {
  final rango = ref.watch(rangoReporteProvider);
  final result = await ObtenerReportePagos(ref.watch(_repositoryProvider))
      .call(desde: rango?.start, hasta: rango?.end);
  return result.fold((f) => throw f, (r) => r);
});

// -------------------- Acciones --------------------

class AdminController {
  const AdminController(this._ref);
  final Ref _ref;

  Future<String?> cambiarEstadoReserva(int id, EstadoReserva estado) async {
    final result = await CambiarEstadoReserva(_ref.read(_repositoryProvider))
        .call(id, estado);
    return result.fold((f) => f.message, (_) {
      _ref.invalidate(reservasAdminProvider);
      _ref.invalidate(resumenDiaProvider);
      return null; // sin error
    });
  }

  Future<String?> cambiarEstadoHabitacion(
    int id,
    EstadoHabitacion estado,
  ) async {
    final result = await CambiarEstadoHabitacion(_ref.read(_repositoryProvider))
        .call(id, estado);
    return result.fold((f) => f.message, (_) {
      _ref.invalidate(habitacionesAdminProvider);
      _ref.invalidate(resumenDiaProvider);
      return null;
    });
  }
}

final adminControllerProvider = Provider((ref) => AdminController(ref));
