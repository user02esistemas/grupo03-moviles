import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/habitacion.dart';
import '../repositories/habitaciones_repository.dart';

class ObtenerDetalleHabitacion {
  const ObtenerDetalleHabitacion(this._repository);
  final HabitacionesRepository _repository;

  Future<Either<Failure, Habitacion>> call(int idHabitacion) {
    return _repository.obtenerDetalle(idHabitacion);
  }
}