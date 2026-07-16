// UBICACIÓN: lib/features/pagos/domain/repositories/pagos_repository.dart
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/intencion_pago.dart';
import '../entities/pago.dart';

abstract interface class PagosRepository {
  /// Crea la intención de pago para una reserva. El backend genera el
  /// formToken de Izipay y devuelve la URL del checkout embebido.
  Future<Either<Failure, IntencionPago>> crearIntencion(int idReserva);

  /// Consulta el estado real del pago (actualizado por el IPN de Izipay).
  Future<Either<Failure, Pago>> consultar(int idPago);
}