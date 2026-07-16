// UBICACIÓN: lib/features/notificaciones/data/repositories/notificaciones_repository_impl.dart
import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/notificacion.dart';
import '../../domain/repositories/notificaciones_repository.dart';
import '../datasources/notificaciones_remote_datasource.dart';

class NotificacionesRepositoryImpl implements NotificacionesRepository {
  const NotificacionesRepositoryImpl(this._remote);
  final NotificacionesRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<Notificacion>>> obtener() =>
      _guard(() => _remote.obtener());

  @override
  Future<Either<Failure, Unit>> marcarLeida(int idNotificacion) =>
      _guardUnit(() => _remote.marcarLeida(idNotificacion));

  @override
  Future<Either<Failure, Unit>> marcarTodasLeidas() =>
      _guardUnit(() => _remote.marcarTodasLeidas());

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } catch (e) {
      return Left(_mapear(e));
    }
  }

  Future<Either<Failure, Unit>> _guardUnit(Future<void> Function() action) async {
    try {
      await action();
      return const Right(unit);
    } catch (e) {
      return Left(_mapear(e));
    }
  }

  Failure _mapear(Object e) {
    if (e is NetworkException) return NetworkFailure(e.message);
    if (e is UnauthorizedException) return AuthFailure(e.message);
    if (e is ServerException) return ServerFailure(e.message);
    return const UnexpectedFailure();
  }
}