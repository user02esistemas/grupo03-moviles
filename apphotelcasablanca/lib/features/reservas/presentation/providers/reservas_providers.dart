import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/infra_providers.dart';
import '../../../../core/error/failures.dart';
import '../../../habitaciones/presentation/providers/habitaciones_providers.dart';
import '../../data/datasources/reservas_remote_datasource.dart';
import '../../data/repositories/reservas_repository_impl.dart';
import '../../domain/entities/crear_reserva_params.dart';
import '../../domain/entities/reserva.dart';
import '../../domain/repositories/reservas_repository.dart';
import '../../domain/usecases/cancelar_reserva.dart';
import '../../domain/usecases/crear_reserva.dart';
import '../../domain/usecases/obtener_mis_reservas.dart';

// -------------------- DI --------------------

final _remoteProvider = Provider<ReservasRemoteDataSource>(
  (ref) => ReservasRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final _repositoryProvider = Provider<ReservasRepository>(
  (ref) => ReservasRepositoryImpl(ref.watch(_remoteProvider)),
);

final _crearProvider =
    Provider((ref) => CrearReserva(ref.watch(_repositoryProvider)));
final _misReservasProvider =
    Provider((ref) => ObtenerMisReservas(ref.watch(_repositoryProvider)));
final _cancelarProvider =
    Provider((ref) => CancelarReserva(ref.watch(_repositoryProvider)));

// -------------------- Datos --------------------

/// Lista de reservas del usuario autenticado.
final misReservasProvider = FutureProvider<List<Reserva>>((ref) async {
  final result = await ref.watch(_misReservasProvider).call();
  return result.fold((f) => throw f, (lista) => lista);
});

// -------------------- Acciones --------------------

/// Orquesta crear/cancelar y refresca las vistas afectadas (mis reservas y el
/// catálogo, porque cambió la disponibilidad).
class ReservasController {
  const ReservasController(this._ref);
  final Ref _ref;

  Future<Either<Failure, Reserva>> crear(CrearReservaParams params) async {
    final result = await _ref.read(_crearProvider).call(params);
    result.fold((_) {}, (_) => _refrescar());
    return result;
  }

  Future<Either<Failure, Unit>> cancelar(int idReserva) async {
    final result = await _ref.read(_cancelarProvider).call(idReserva);
    result.fold((_) {}, (_) => _refrescar());
    return result;
  }

  void _refrescar() {
    _ref.invalidate(misReservasProvider);
    _ref.invalidate(habitacionesProvider); // la disponibilidad cambió
  }
}

final reservasControllerProvider =
    Provider((ref) => ReservasController(ref));