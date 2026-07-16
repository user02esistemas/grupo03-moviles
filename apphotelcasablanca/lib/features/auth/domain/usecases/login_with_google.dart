import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/usuario.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso: iniciar sesión con Google.
class LoginWithGoogle {
  const LoginWithGoogle(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, Usuario>> call() => _repository.loginWithGoogle();
}