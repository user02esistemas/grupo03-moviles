import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/usuario.dart';

/// Contrato de autenticación. La implementación vive en la capa data.
/// Devuelve Either<Failure, T>: izquierda = error controlado, derecha = éxito.
abstract interface class AuthRepository {
  Future<Either<Failure, Usuario>> login({
    required String correo,
    required String password,
  });

  Future<Either<Failure, Usuario>> register({
    required String nombre,
    required String apellido,
    required String correo,
    required String password,
    String? telefono,
  });

  Future<Either<Failure, Usuario>> loginWithGoogle();

  Future<Either<Failure, Unit>> logout();

  /// Recupera la sesión guardada al abrir la app (si hay token válido).
  Future<Either<Failure, Usuario?>> currentUser();
}