import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/crear_reserva_params.dart';
import '../entities/reserva.dart';
import '../repositories/reservas_repository.dart';

class CrearReserva {
  const CrearReserva(this._repository);
  final ReservasRepository _repository;

  Future<Either<Failure, Reserva>> call(CrearReservaParams params) =>
      _repository.crear(params);
}