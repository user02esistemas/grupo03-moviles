import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/notificacion.dart';
import '../repositories/notificaciones_repository.dart';

class ObtenerNotificaciones {
  const ObtenerNotificaciones(this._repository);
  final NotificacionesRepository _repository;

  Future<Either<Failure, List<Notificacion>>> call() => _repository.obtener();
}