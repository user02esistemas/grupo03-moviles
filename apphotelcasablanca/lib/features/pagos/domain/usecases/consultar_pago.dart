import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/pago.dart';
import '../repositories/pagos_repository.dart';

class ConsultarPago {
  const ConsultarPago(this._repository);
  final PagosRepository _repository;

  Future<Either<Failure, Pago>> call(int idPago) =>
      _repository.consultar(idPago);
}