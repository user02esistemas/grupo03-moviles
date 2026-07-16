import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/usuario.dart';
import '../../domain/entities/perfil_params.dart';
import '../../domain/repositories/perfil_repository.dart';
import '../datasources/perfil_remote_datasource.dart';

class PerfilRepositoryImpl implements PerfilRepository {
  const PerfilRepositoryImpl(this._remote);
  final PerfilRemoteDataSource _remote;

  @override
  Future<Either<Failure, Usuario>> actualizar(
    ActualizarPerfilParams params,
  ) async {
    try {
      return Right(await _remote.actualizar(params));
    } catch (e) {
      return Left(_mapear(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> cambiarPassword(
    CambiarPasswordParams params,
  ) async {
    try {
      await _remote.cambiarPassword(params);
      return const Right(unit);
    } on UnauthorizedException {
      // 401 aquí = la contraseña actual no coincide.
      return const Left(AuthFailure('La contraseña actual es incorrecta'));
    } catch (e) {
      return Left(_mapear(e));
    }
  }

  Failure _mapear(Object e) {
    if (e is NetworkException) return NetworkFailure(e.message);
    if (e is UnauthorizedException) return AuthFailure(e.message);
    if (e is ConflictException) return ConflictFailure(e.message);
    if (e is ServerException) return ServerFailure(e.message);
    return const UnexpectedFailure();
  }
}
