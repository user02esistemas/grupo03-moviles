import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/infra_providers.dart';
import '../../../../core/error/failures.dart';
import '../../../habitaciones/presentation/providers/habitaciones_providers.dart';
import '../../../reservas/presentation/providers/reservas_providers.dart';
import '../../data/datasources/pagos_remote_datasource.dart';
import '../../data/repositories/pagos_repository_impl.dart';
import '../../domain/entities/intencion_pago.dart';
import '../../domain/entities/pago.dart';
import '../../domain/repositories/pagos_repository.dart';
import '../../domain/usecases/consultar_pago.dart';
import '../../domain/usecases/crear_intencion_pago.dart';

// -------------------- DI --------------------

final _remoteProvider = Provider<PagosRemoteDataSource>(
  (ref) => PagosRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final _repositoryProvider = Provider<PagosRepository>(
  (ref) => PagosRepositoryImpl(ref.watch(_remoteProvider)),
);

final _crearIntencionProvider =
    Provider((ref) => CrearIntencionPago(ref.watch(_repositoryProvider)));
final _consultarProvider =
    Provider((ref) => ConsultarPago(ref.watch(_repositoryProvider)));

// -------------------- Acciones --------------------

class PagosController {
  const PagosController(this._ref);
  final Ref _ref;

  Future<Either<Failure, IntencionPago>> crearIntencion(int idReserva) {
    return _ref.read(_crearIntencionProvider).call(idReserva);
  }

  Future<Either<Failure, Pago>> consultar(int idPago) async {
    final result = await _ref.read(_consultarProvider).call(idPago);
    // Si el pago quedó confirmado, la reserva pasó a confirmada: refrescar.
    result.fold((_) {}, (pago) {
      if (pago.estaPagado) {
        _ref.invalidate(misReservasProvider);
        _ref.invalidate(habitacionesProvider);
      }
    });
    return result;
  }
}

final pagosControllerProvider = Provider((ref) => PagosController(ref));