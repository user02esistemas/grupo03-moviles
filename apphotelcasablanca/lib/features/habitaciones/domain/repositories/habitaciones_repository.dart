import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/filtro_busqueda.dart';
import '../entities/habitacion.dart';

abstract interface class HabitacionesRepository {
  /// Lista de habitaciones. Si el filtro trae fechas, el backend devuelve solo
  /// las disponibles en ese rango con capacidad suficiente.
  Future<Either<Failure, List<Habitacion>>> obtenerHabitaciones(
    FiltroBusqueda filtro,
  );

  Future<Either<Failure, Habitacion>> obtenerDetalle(int idHabitacion);
}