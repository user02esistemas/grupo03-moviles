import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/reservas_repository.dart';

class CancelarReserva {
  const CancelarReserva(this._repository);
  final ReservasRepository _repository;

  Future<Either<Failure, Unit>> call(int idReserva) =>
      _repository.cancelar(idReserva);
}