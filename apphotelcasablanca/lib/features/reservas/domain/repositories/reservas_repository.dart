import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/crear_reserva_params.dart';
import '../entities/reserva.dart';

abstract interface class ReservasRepository {
  /// Crea la reserva (estado inicial: pendiente). Si las fechas se solapan con
  /// otra reserva activa, el backend devuelve 409 -> ConflictFailure.
  Future<Either<Failure, Reserva>> crear(CrearReservaParams params);

  Future<Either<Failure, List<Reserva>>> misReservas();

  Future<Either<Failure, Unit>> cancelar(int idReserva);
}