// UBICACIÓN: lib/features/habitaciones/data/repositories/habitaciones_repository_impl.dart
import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/filtro_busqueda.dart';
import '../../domain/entities/habitacion.dart';
import '../../domain/repositories/habitaciones_repository.dart';
import '../datasources/habitaciones_remote_datasource.dart';

class HabitacionesRepositoryImpl implements HabitacionesRepository {
  const HabitacionesRepositoryImpl(this._remote);
  final HabitacionesRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<Habitacion>>> obtenerHabitaciones(
    FiltroBusqueda filtro,
  ) {
    return _guard(() => _remote.obtenerHabitaciones(filtro));
  }

  @override
  Future<Either<Failure, Habitacion>> obtenerDetalle(int idHabitacion) {
    return _guard(() => _remote.obtenerDetalle(idHabitacion));
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}