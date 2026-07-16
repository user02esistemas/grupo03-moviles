// UBICACIÓN: lib/features/notificaciones/presentation/providers/notificaciones_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/infra_providers.dart';
import '../../domain/entities/notificacion.dart';
import '../../data/datasources/notificaciones_remote_datasource.dart';
import '../../data/repositories/notificaciones_repository_impl.dart';
import '../../domain/repositories/notificaciones_repository.dart';
import '../../domain/usecases/marcar_leida.dart';
import '../../domain/usecases/obtener_notificaciones.dart';

// -------------------- DI --------------------

final _remoteProvider = Provider<NotificacionesRemoteDataSource>(
  (ref) => NotificacionesRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final _repositoryProvider = Provider<NotificacionesRepository>(
  (ref) => NotificacionesRepositoryImpl(ref.watch(_remoteProvider)),
);

final _obtenerProvider =
    Provider((ref) => ObtenerNotificaciones(ref.watch(_repositoryProvider)));
final _marcarLeidaProvider =
    Provider((ref) => MarcarLeida(ref.watch(_repositoryProvider)));
final _marcarTodasProvider =
    Provider((ref) => MarcarTodasLeidas(ref.watch(_repositoryProvider)));

// -------------------- Datos --------------------

final notificacionesProvider = FutureProvider<List<Notificacion>>((ref) async {
  final result = await ref.watch(_obtenerProvider).call();
  return result.fold((f) => throw f, (lista) => lista);
});

/// Contador de no leídas para el badge del bottom nav. 0 si aún no cargó.
final notificacionesNoLeidasProvider = Provider<int>((ref) {
  final async = ref.watch(notificacionesProvider);
  return async.maybeWhen(
    data: (lista) => lista.where((n) => !n.leida).length,
    orElse: () => 0,
  );
});

// -------------------- Acciones --------------------

class NotificacionesController {
  const NotificacionesController(this._ref);
  final Ref _ref;

  Future<void> marcarLeida(int id) async {
    final result = await _ref.read(_marcarLeidaProvider).call(id);
    result.fold((_) {}, (_) => _ref.invalidate(notificacionesProvider));
  }

  Future<void> marcarTodasLeidas() async {
    final result = await _ref.read(_marcarTodasProvider).call();
    result.fold((_) {}, (_) => _ref.invalidate(notificacionesProvider));
  }
}

final notificacionesControllerProvider =
    Provider((ref) => NotificacionesController(ref));