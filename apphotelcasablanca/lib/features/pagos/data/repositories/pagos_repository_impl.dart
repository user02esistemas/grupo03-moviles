// UBICACIÓN: lib/features/pagos/data/repositories/pagos_repository_impl.dart
import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/intencion_pago.dart';
import '../../domain/entities/pago.dart';
import '../../domain/repositories/pagos_repository.dart';
import '../datasources/pagos_remote_datasource.dart';

class PagosRepositoryImpl implements PagosRepository {
  const PagosRepositoryImpl(this._remote);
  final PagosRemoteDataSource _remote;

  @override
  Future<Either<Failure, IntencionPago>> crearIntencion(int idReserva) {
    return _guard(() => _remote.crearIntencion(idReserva));
  }

  @override
  Future<Either<Failure, Pago>> consultar(int idPago) {
    return _guard(() => _remote.consultar(idPago));
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