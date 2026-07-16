import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/reserva.dart';
import '../repositories/reservas_repository.dart';

class ObtenerMisReservas {
  const ObtenerMisReservas(this._repository);
  final ReservasRepository _repository;

  Future<Either<Failure, List<Reserva>>> call() => _repository.misReservas();
}