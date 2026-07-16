
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/intencion_pago.dart';
import '../repositories/pagos_repository.dart';

class CrearIntencionPago {
  const CrearIntencionPago(this._repository);
  final PagosRepository _repository;

  Future<Either<Failure, IntencionPago>> call(int idReserva) =>
      _repository.crearIntencion(idReserva);
}