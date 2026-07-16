
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/infra_providers.dart';
import '../../domain/entities/filtro_busqueda.dart';
import '../../domain/entities/habitacion.dart';
import '../../data/datasources/habitaciones_remote_datasource.dart';
import '../../data/repositories/habitaciones_repository_impl.dart';
import '../../domain/repositories/habitaciones_repository.dart';
import '../../domain/usecases/obtener_detalle_habitacion.dart';
import '../../domain/usecases/obtener_habitaciones.dart';

// -------------------- DI --------------------

final _remoteProvider = Provider<HabitacionesRemoteDataSource>((ref) {
  return HabitacionesRemoteDataSourceImpl(ref.watch(dioProvider));
});

final _repositoryProvider = Provider<HabitacionesRepository>((ref) {
  return HabitacionesRepositoryImpl(ref.watch(_remoteProvider));
});

final _obtenerHabitacionesProvider = Provider(
  (ref) => ObtenerHabitaciones(ref.watch(_repositoryProvider)),
);

final _obtenerDetalleProvider = Provider(
  (ref) => ObtenerDetalleHabitacion(ref.watch(_repositoryProvider)),
);

// -------------------- Estado del filtro --------------------

class FiltroNotifier extends Notifier<FiltroBusqueda> {
  @override
  FiltroBusqueda build() => const FiltroBusqueda();

  void setFechas(DateTime inicio, DateTime fin) =>
      state = state.copyWith(fechaInicio: inicio, fechaFin: fin);

  void setPersonas(int personas) =>
      state = state.copyWith(personas: personas.clamp(1, 20));

  void limpiar() => state = const FiltroBusqueda();
}

final filtroProvider =
    NotifierProvider<FiltroNotifier, FiltroBusqueda>(FiltroNotifier.new);

// -------------------- Datos (AsyncValue) --------------------

/// Lista de habitaciones según el filtro actual. Se recalcula solo cuando
/// cambia el filtro. Devuelve la lista o lanza el Failure (lo captura la UI).
final habitacionesProvider = FutureProvider<List<Habitacion>>((ref) async {
  final filtro = ref.watch(filtroProvider);
  final result = await ref.watch(_obtenerHabitacionesProvider).call(filtro);
  return result.fold((f) => throw f, (lista) => lista);
});

/// Detalle de una habitación por id.
final habitacionDetalleProvider =
    FutureProvider.family<Habitacion, int>((ref, id) async {
  final result = await ref.watch(_obtenerDetalleProvider).call(id);
  return result.fold((f) => throw f, (h) => h);
});