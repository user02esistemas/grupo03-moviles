import 'package:dartz/dartz.dart';

import '../../../../core/enums/estado_habitacion.dart';
import '../../../../core/enums/estado_reserva.dart';
import '../../../../core/error/failures.dart';
import '../entities/habitacion_admin.dart';
import '../entities/reporte_pagos.dart';
import '../entities/reserva_admin.dart';
import '../entities/resumen_dia.dart';
import '../repositories/admin_repository.dart';

class ObtenerResumenDia {
  const ObtenerResumenDia(this._r);
  final AdminRepository _r;
  Future<Either<Failure, ResumenDia>> call() => _r.resumenDia();
}

class ObtenerReservasAdmin {
  const ObtenerReservasAdmin(this._r);
  final AdminRepository _r;
  Future<Either<Failure, List<ReservaAdmin>>> call({EstadoReserva? estado}) =>
      _r.reservas(estado: estado);
}

class CambiarEstadoReserva {
  const CambiarEstadoReserva(this._r);
  final AdminRepository _r;
  Future<Either<Failure, Unit>> call(int id, EstadoReserva estado) =>
      _r.cambiarEstadoReserva(id, estado);
}

class ObtenerHabitacionesAdmin {
  const ObtenerHabitacionesAdmin(this._r);
  final AdminRepository _r;
  Future<Either<Failure, List<HabitacionAdmin>>> call() => _r.habitaciones();
}

class CambiarEstadoHabitacion {
  const CambiarEstadoHabitacion(this._r);
  final AdminRepository _r;
  Future<Either<Failure, Unit>> call(int id, EstadoHabitacion estado) =>
      _r.cambiarEstadoHabitacion(id, estado);
}

class ObtenerReportePagos {
  const ObtenerReportePagos(this._r);
  final AdminRepository _r;
  Future<Either<Failure, ReportePagos>> call({DateTime? desde, DateTime? hasta}) =>
      _r.reportePagos(desde: desde, hasta: hasta);
}