import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/filtro_busqueda.dart';
import '../entities/habitacion.dart';
import '../repositories/habitaciones_repository.dart';

class ObtenerHabitaciones {
  const ObtenerHabitaciones(this._repository);
  final HabitacionesRepository _repository;

  Future<Either<Failure, List<Habitacion>>> call(FiltroBusqueda filtro) {
    return _repository.obtenerHabitaciones(filtro);
  }
}