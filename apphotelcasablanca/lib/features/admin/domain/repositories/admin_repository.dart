import 'package:dartz/dartz.dart';

import '../../../../core/enums/estado_habitacion.dart';
import '../../../../core/enums/estado_reserva.dart';
import '../../../../core/error/failures.dart';
import '../entities/habitacion_admin.dart';
import '../entities/reporte_pagos.dart';
import '../entities/reserva_admin.dart';
import '../entities/resumen_dia.dart';

abstract interface class AdminRepository {
  Future<Either<Failure, ResumenDia>> resumenDia();

  Future<Either<Failure, List<ReservaAdmin>>> reservas({EstadoReserva? estado});
  Future<Either<Failure, Unit>> cambiarEstadoReserva(
    int idReserva,
    EstadoReserva nuevoEstado,
  );

  Future<Either<Failure, List<HabitacionAdmin>>> habitaciones();
  Future<Either<Failure, Unit>> cambiarEstadoHabitacion(
    int idHabitacion,
    EstadoHabitacion nuevoEstado,
  );

  Future<Either<Failure, ReportePagos>> reportePagos({
    DateTime? desde,
    DateTime? hasta,
  });
}