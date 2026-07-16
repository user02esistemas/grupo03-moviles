import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/usuario.dart';
import '../repositories/auth_repository.dart';

class LoginParams {
  const LoginParams({required this.correo, required this.password});
  final String correo;
  final String password;
}

/// Caso de uso: iniciar sesión con correo y contraseña.
class Login {
  const Login(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, Usuario>> call(LoginParams params) {
    return _repository.login(
      correo: params.correo,
      password: params.password,
    );
  }
}