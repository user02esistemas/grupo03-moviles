import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/notificaciones_repository.dart';

class MarcarLeida {
  const MarcarLeida(this._repository);
  final NotificacionesRepository _repository;

  Future<Either<Failure, Unit>> call(int idNotificacion) =>
      _repository.marcarLeida(idNotificacion);
}

class MarcarTodasLeidas {
  const MarcarTodasLeidas(this._repository);
  final NotificacionesRepository _repository;

  Future<Either<Failure, Unit>> call() => _repository.marcarTodasLeidas();
}