import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/notificacion.dart';

abstract interface class NotificacionesRepository {
  Future<Either<Failure, List<Notificacion>>> obtener();
  Future<Either<Failure, Unit>> marcarLeida(int idNotificacion);
  Future<Either<Failure, Unit>> marcarTodasLeidas();
}