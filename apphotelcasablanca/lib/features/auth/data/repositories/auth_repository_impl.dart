import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/usuario.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_response_model.dart';

/// Implementa el contrato del dominio. Orquesta datasource + storage y
/// convierte las excepciones en Failures.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSourceImpl remote,
    required SecureStorage storage,
  })  : _remote = remote,
        _storage = storage;

  final AuthRemoteDataSourceImpl _remote;
  final SecureStorage _storage;

  @override
  Future<Either<Failure, Usuario>> login({
    required String correo,
    required String password,
  }) {
    return _guard(() => _remote.login(correo: correo, password: password));
  }

  @override
  Future<Either<Failure, Usuario>> register({
    required String nombre,
    required String apellido,
    required String correo,
    required String password,
    String? telefono,
  }) {
    return _guard(
      () => _remote.register(
        nombre: nombre,
        apellido: apellido,
        correo: correo,
        password: password,
        telefono: telefono,
      ),
    );
  }

  @override
  Future<Either<Failure, Usuario>> loginWithGoogle() {
    return _guard(() => _remote.loginWithGoogle());
  }

  @override
  Future<Either<Failure, Unit>> logout() async {
    try {
      await _remote.signOutGoogle();
    } catch (_) {
      // Ignoramos fallos de Google al desloguear.
    }
    await _storage.clear();
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Usuario?>> currentUser() async {
    final token = await _storage.accessToken;
    if (token == null) return const Right(null);
    try {
      final usuario = await _remote.me();
      return Right(usuario);
    } on UnauthorizedException {
      await _storage.clear();
      return const Right(null);
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  /// Ejecuta una llamada que devuelve tokens + usuario, guarda los tokens y
  /// mapea excepciones a Failures.
  Future<Either<Failure, Usuario>> _guard(
    Future<AuthResponseModel> Function() action,
  ) async {
    try {
      final res = await action();
      await _storage.saveTokens(
        accessToken: res.accessToken,
        refreshToken: res.refreshToken,
      );
      return Right(res.usuario);
    } on UnauthorizedException catch (e) {
      return Left(AuthFailure(e.message));
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message));
    } on GoogleCancelledException {
      return const Left(CancelledFailure('Inicio con Google cancelado'));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}
